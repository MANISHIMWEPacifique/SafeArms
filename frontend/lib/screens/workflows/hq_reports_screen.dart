import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../../utils/pdf_report_generator.dart';

/// HQ Firearm Commander – National Firearm Oversight Reports
/// Report types: Firearm Registration & History, Custody Chain, Ballistic Traceability, Anomaly Oversight
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
  final TextEditingController _unitNameController = TextEditingController();
  String _selectedReportType = 'firearm_history';

  // Data state
  bool _isLoading = false;
  bool _reportGenerated = false;
  String? _error;
  Map<String, dynamic> _reportData = {};
  List<Map<String, dynamic>> _units = [];

  final List<Map<String, String>> _reportTypes = [
    {'value': 'firearm_history', 'label': 'Firearm Registration & History'},
    {'value': 'custody_timeline', 'label': 'Custody Chain Report'},
    {'value': 'ballistic_summary', 'label': 'Ballistic Traceability Report'},
    {'value': 'anomaly_summary', 'label': 'Anomaly Oversight Report'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _unitNameController.dispose();
    super.dispose();
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
      if (_unitNameController.text.trim().isNotEmpty) {
        // Find unit by name
        final matchedUnit = _units.firstWhere(
          (u) => (u['unit_name']?.toString() ?? '').toLowerCase().contains(
                _unitNameController.text.trim().toLowerCase(),
              ),
          orElse: () => {},
        );
        if (matchedUnit.isNotEmpty) {
          queryParams['unit_id'] = matchedUnit['unit_id'].toString();
        }
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
      if (_unitNameController.text.isNotEmpty) {
        metadata['Unit'] = _unitNameController.text;
      }
      if (_dateFrom != null && _dateTo != null) {
        metadata['Date Range'] =
            '${DateFormat('MMM d, yyyy').format(_dateFrom!)} \u2013 ${DateFormat('MMM d, yyyy').format(_dateTo!)}';
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
            'National Firearm Oversight Reports',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Generate firearm registration, custody chain, ballistic traceability, and anomaly reports across all units',
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
            'Select report type, fill in the fields and submit',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Report Type Selection
          const Text('Select Report Type',
              style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _reportTypes.map((rt) {
              final isSelected = _selectedReportType == rt['value'];
              return InkWell(
                onTap: () => setState(() => _selectedReportType = rt['value']!),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected
                            ? const Color(0xFF1E88E5)
                            : const Color(0xFF78909C),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rt['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF1E88E5)
                              : const Color(0xFFB0BEC5),
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Date Range + Unit Name Row
          Row(
            children: [
              Expanded(
                child: _buildFormDateField('Start Date', _dateFrom, (date) {
                  setState(() => _dateFrom = date);
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormDateField('End Date', _dateTo, (date) {
                  setState(() => _dateTo = date);
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormTextField(
                  'Unit Name (optional)',
                  _unitNameController,
                  'Type unit name to filter',
                  Icons.business,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateReport,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Generate Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
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
                          : const Color(0xFF37404F).withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const Spacer(),
              if (_unitNameController.text.isNotEmpty ||
                  _dateFrom != null ||
                  _dateTo != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _unitNameController.clear();
                      _dateFrom = null;
                      _dateTo = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF78909C)),
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
    IconData icon,
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
              prefixIcon: Icon(icon, color: const Color(0xFF78909C), size: 18),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      if (states.contains(WidgetState.selected))
                        return Colors.white;
                      if (states.contains(WidgetState.disabled))
                        return const Color(0xFF546E7A);
                      return Colors.white;
                    }),
                    dayBackgroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected))
                        return const Color(0xFF1E88E5);
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

  Widget _buildReportContent() {
    final reportLabel = _reportTypes
        .firstWhere((r) => r['value'] == _selectedReportType)['label']!;
    final generatedAt =
        DateFormat('MMM d, yyyy – h:mm a').format(DateTime.now());
    final unitName = _unitNameController.text.trim().isNotEmpty
        ? _unitNameController.text.trim()
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
          _buildReportHeader(reportLabel, generatedAt, unitName),
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
                    _fmtDate(f['acquisition_date']?.toString() ??
                        f['created_at']?.toString()),
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
            'Rifling',
            'Firing Pin',
            'Recorded'
          ],
          rows: profiles
              .map((p) => [
                    p['serial_number']?.toString() ?? '',
                    p['caliber']?.toString() ?? '',
                    p['rifling_characteristics']?.toString() ?? '',
                    p['firing_pin_impression']?.toString() ?? '',
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
