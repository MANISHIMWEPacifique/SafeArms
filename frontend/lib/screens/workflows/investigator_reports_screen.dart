import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../../utils/pdf_report_generator.dart';
import '../../widgets/empty_state_widget.dart';

/// Investigator – Investigation & Traceability Reports
/// Report types: Firearm History & Custody, Custody Timeline, Ballistic Reference Traceability
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
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _selectedReportType = 'firearm_history';

  // Data state
  bool _isLoading = false;
  bool _reportGenerated = false;
  String? _error;
  Map<String, dynamic> _reportData = {};

  final List<Map<String, String>> _reportTypes = [
    {'value': 'firearm_history', 'label': 'Firearm History & Custody Chain'},
    {'value': 'ballistic_summary', 'label': 'Ballistic Reference Traceability'},
  ];

  @override
  void dispose() {
    _serialController.dispose();
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

  Future<void> _exportPdf() async {
    try {
      final reportLabel = _reportTypes
          .firstWhere((r) => r['value'] == _selectedReportType)['label']!;
      final metadata = <String, String>{};
      if (_serialController.text.isNotEmpty) {
        metadata['Serial Number'] = _serialController.text;
      }
      if (_dateFrom != null && _dateTo != null) {
        metadata['Date Range'] =
            '${DateFormat('MMM d, yyyy').format(_dateFrom!)} – ${DateFormat('MMM d, yyyy').format(_dateTo!)}';
      }
      await PdfReportGenerator.generate(
        reportTitle: reportLabel,
        reportType: _selectedReportType,
        reportData: _reportData,
        metadata: metadata,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: const Color(0xFFEF5350),
          ),
        );
      }
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
            'Investigation & Traceability Reports',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Generate read-only reports linking firearm records, custody chains, and ballistic reference data for investigations',
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Parameters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Fill in the fields below and click Generate to create your report',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Report Type Selection
          const Text('SELECT REPORT TYPE',
              style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: _reportTypes.map((rt) {
              final isSelected = _selectedReportType == rt['value'];
              final isFirst = _reportTypes.first == rt;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: isFirst ? 0 : 12),
                  child: InkWell(
                    onTap: () =>
                        setState(() => _selectedReportType = rt['value']!),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E88E5).withValues(alpha: 0.15)
                            : const Color(0xFF1A1F2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1E88E5)
                              : const Color(0xFF37404F),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            rt['value'] == 'firearm_history'
                                ? Icons.description_outlined
                                : Icons.track_changes,
                            color: isSelected
                                ? const Color(0xFF1E88E5)
                                : const Color(0xFF78909C),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              rt['label']!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF1E88E5)
                                    : const Color(0xFFB0BEC5),
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          _buildFormTextField(
            'FIREARM SERIAL NUMBER',
            _serialController,
            'Enter serial number',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFormDateField('START DATE', _dateFrom, (date) {
                  setState(() => _dateFrom = date);
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormDateField('END DATE', _dateTo, (date) {
                  setState(() => _dateTo = date);
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateReport,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Generate Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reportGenerated ? _exportPdf : null,
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Export PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _reportGenerated
                            ? const Color(0xFFB0BEC5)
                            : const Color(0xFF546E7A),
                        side: BorderSide(
                            color: _reportGenerated
                                ? const Color(0xFF37404F)
                                : const Color(0xFF37404F)
                                    .withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_serialController.text.isNotEmpty ||
                              _dateFrom != null ||
                              _dateTo != null)
                          ? () {
                              setState(() {
                                _serialController.clear();
                                _dateFrom = null;
                                _dateTo = null;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: (_serialController.text.isNotEmpty ||
                                _dateFrom != null ||
                                _dateTo != null)
                            ? const Color(0xFFB0BEC5)
                            : const Color(0xFF546E7A),
                        side: BorderSide(
                            color: (_serialController.text.isNotEmpty ||
                                    _dateFrom != null ||
                                    _dateTo != null)
                                ? const Color(0xFF37404F)
                                : const Color(0xFF37404F)
                                    .withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
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

  Widget _buildFormTextField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFF78909C), fontSize: 13),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormDateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF1E88E5),
                    onPrimary: Colors.white,
                    surface: Color(0xFF252A3A),
                    onSurface: Colors.white,
                  ),
                  dialogTheme: const DialogThemeData(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  datePickerTheme: DatePickerThemeData(
                    backgroundColor: const Color(0xFF252A3A),
                    headerBackgroundColor: const Color(0xFF1A1F2E),
                    headerForegroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    dayStyle: const TextStyle(color: Colors.white),
                    yearStyle: const TextStyle(color: Colors.white),
                    dayForegroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      if (states.contains(WidgetState.disabled)) {
                        return const Color(0xFF546E7A);
                      }
                      return Colors.white;
                    }),
                    dayBackgroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF1E88E5);
                      }
                      return Colors.transparent;
                    }),
                    todayForegroundColor:
                        WidgetStateProperty.all(const Color(0xFF42A5F5)),
                    todayBackgroundColor:
                        WidgetStateProperty.all(Colors.transparent),
                    todayBorder: const BorderSide(color: Color(0xFF42A5F5)),
                  ),
                ),
                child: child!,
              ),
            );
            if (date != null) onChanged(date);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: value != null
                      ? const Color(0xFF1E88E5)
                      : const Color(0xFF78909C),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  value != null
                      ? DateFormat('MMM d, yyyy').format(value)
                      : 'Select date',
                  style: TextStyle(
                    color:
                        value != null ? Colors.white : const Color(0xFF78909C),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Old methods replaced by _buildFormTextField and _buildFormDateField above

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
                    _fmtDate(f['acquisition_date']?.toString() ??
                        f['created_at']?.toString()),
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
              'Serial Number',
              'Officer',
              'Unit',
              'Issued Date',
              'Returned Date',
              'Duration'
            ],
            rows: List<Map<String, dynamic>>.from(
                    _reportData['custody_records'] ?? [])
                .map((c) => [
                      c['serial_number']?.toString() ?? '',
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
        _buildSectionTitle('Ballistic Reference Profiles & Traceability'),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Firearm: ${p['serial_number'] ?? 'N/A'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Ref ID: ${p['ballistic_id']?.toString() ?? 'N/A'}',
                      style: const TextStyle(
                        color: Color(0xFF78909C),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMetadataGrid(p),
                const SizedBox(height: 16),
                _buildRecentCustodyForBallistic(p['firearm_id']),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentCustodyForBallistic(dynamic firearmId) {
    if (firearmId == null) return const SizedBox.shrink();

    final logs = List<Map<String, dynamic>>.from(
        _reportData['recent_custody_logs'] ?? []);

    final firearmLogs =
        logs.where((l) => l['firearm_id'] == firearmId).toList();

    if (firearmLogs.isEmpty) {
      return const Text('No recent custody history found.',
          style: TextStyle(
              color: Color(0xFF78909C),
              fontSize: 13,
              fontStyle: FontStyle.italic));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Custody Chain',
          style: TextStyle(
              color: Color(0xFF1E88E5),
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...firearmLogs.take(5).map((log) {
          final outDate = _fmtDate(log['issued_at']?.toString());
          final inDate = log['returned_at'] != null
              ? _fmtDate(log['returned_at']?.toString())
              : 'Current';
          final officer = log['officer_name'] ?? 'Unknown';
          final unit = log['unit_name'] ?? 'Unknown Unit';

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_right,
                    size: 16, color: Color(0xFF78909C)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$outDate - $inDate • $officer ($unit)',
                    style:
                        const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMetadataGrid(Map<String, dynamic> profile) {
    final fields = [
      {'label': 'Rifling Characteristics', 'key': 'rifling_characteristics'},
      {'label': 'Firing Pin Impression', 'key': 'firing_pin_impression'},
      {'label': 'Ejector Marks', 'key': 'ejector_marks'},
      {'label': 'Extractor Marks', 'key': 'extractor_marks'},
      {'label': 'Chamber Marks', 'key': 'chamber_marks'},
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final estimatedTableWidth = columns.length * 170.0;
        final tableWidth =
            estimatedTableWidth > constraints.maxWidth
                ? estimatedTableWidth
                : constraints.maxWidth;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFF252A3A)),
                dataRowColor:
                    WidgetStateProperty.all(const Color(0xFF1A1F2E)),
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
                                          color: Color(0xFFB0BEC5),
                                          fontSize: 13),
                                    ),
                                  ))
                              .toList(),
                        ))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return EmptyStateWidget(
      icon: Icons.inbox_outlined,
      subtitle: message,
      iconSize: 48,
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
