import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// Shared PDF report generator for SafeArms reports.
/// Covers all report types for Investigator, HQ Commander, and Admin dashboards.
class PdfReportGenerator {
  // ── Colours ──
  static const _primaryColor = PdfColor.fromInt(0xFF1E88E5);

  /// Entry point – builds the PDF and triggers a download / share dialog.
  static Future<void> generate({
    required String reportTitle,
    required String reportType,
    required Map<String, dynamic> reportData,
    Map<String, String> metadata = const {},
  }) async {
    // Load Roboto from Google Fonts (cached after first download).
    // Roboto has full Unicode support — fixes en-dash / special-char warnings.
    final baseFont = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final italicFont = await PdfGoogleFonts.robotoItalic();
    final boldItalicFont = await PdfGoogleFonts.robotoBoldItalic();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        italic: italicFont,
        boldItalic: boldItalicFont,
      ),
    );

    final generatedAt =
        DateFormat('MMM d, yyyy – h:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) =>
            _buildPageHeader(reportTitle, generatedAt, metadata),
        footer: (context) => _buildPageFooter(context),
        build: (context) => _buildContent(reportType, reportData),
      ),
    );

    final bytes = await pdf.save();
    final filename =
        'SafeArms_${reportType}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    // sharePdf triggers a file download on web (no popup blocker issues).
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  // ─────────────────────────────────────────────
  // PAGE HEADER
  // ─────────────────────────────────────────────
  static pw.Widget _buildPageHeader(
    String title,
    String generatedAt,
    Map<String, String> metadata,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'SafeArms',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              pw.Text(
                'CONFIDENTIAL',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 24,
            children: [
              _metaItem('Generated', generatedAt),
              ...metadata.entries.map((e) => _metaItem(e.key, e.value)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 0.5),
        ],
      ),
    );
  }

  static pw.Widget _metaItem(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(
          text: '$label: ',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.TextSpan(
          text: value,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // PAGE FOOTER
  // ─────────────────────────────────────────────
  static pw.Widget _buildPageFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Column(
        children: [
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'This document contains administrative firearm and ballistic reference metadata '
                'and does not replace laboratory forensic examination.',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CONTENT ROUTER
  // ─────────────────────────────────────────────
  static List<pw.Widget> _buildContent(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'firearm_history':
        return _firearmHistory(data);
      case 'ballistic_summary':
        return _ballisticSummary(data);
      case 'anomaly_summary':
        return _anomalySummary(data);
      case 'user_activity':
        return _userActivity(data);
      case 'audit_log':
        return _auditLog(data);
      default:
        return [pw.Text('Unknown report type: $type')];
    }
  }

  // ─────────────────────────────────────────────
  // FIREARM HISTORY
  // ─────────────────────────────────────────────
  static List<pw.Widget> _firearmHistory(Map<String, dynamic> data) {
    final firearms = _asList(data['firearms']);
    final custody = _asList(data['custody_records']);
    final anomalies = _asList(data['anomalies']);
    final ballistic = data['ballistic_profile'] as Map<String, dynamic>?;

    final widgets = <pw.Widget>[];

    // Firearm Information
    widgets.add(_sectionTitle('Firearm Information'));
    if (firearms.isEmpty) {
      widgets.add(_emptyNote('No firearm records found.'));
    } else {
      widgets.add(_table(
        headers: [
          'Serial Number',
          'Manufacturer',
          'Model',
          'Type',
          'Caliber',
          'Status',
          'Unit'
        ],
        rows: firearms
            .map((f) => [
                  f['serial_number']?.toString() ?? '',
                  f['manufacturer']?.toString() ?? '',
                  f['model']?.toString() ?? '',
                  f['firearm_type']?.toString() ?? '',
                  f['caliber']?.toString() ?? '',
                  f['current_status']?.toString() ?? '',
                  f['unit_name']?.toString() ?? 'Unassigned',
                ])
            .toList(),
      ));
    }

    // Custody Timeline
    if (custody.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 16));
      widgets.add(_sectionTitle('Custody Timeline'));
      widgets.add(_table(
        headers: [
          'Serial Number',
          'Officer',
          'Unit',
          'Issued',
          'Returned',
          'Duration'
        ],
        rows: custody
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
      ));
    }

    // Anomalies
    if (anomalies.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 16));
      widgets.add(_sectionTitle('Linked Anomalies'));
      widgets.add(_table(
        headers: ['Anomaly ID', 'Severity', 'Status'],
        rows: anomalies
            .map((a) => [
                  a['anomaly_id']?.toString() ?? '',
                  a['severity']?.toString() ?? '',
                  a['status']?.toString() ?? '',
                ])
            .toList(),
      ));
    }

    // Ballistic Profile
    if (ballistic != null) {
      widgets.add(pw.SizedBox(height: 16));
      widgets.add(_sectionTitle('Ballistic Reference Metadata'));
      widgets.add(_keyValueGrid({
        'Rifling Characteristics':
            ballistic['rifling_characteristics']?.toString() ?? '–',
        'Firing Pin Impression':
            ballistic['firing_pin_impression']?.toString() ?? '–',
        'Ejector Marks': ballistic['ejector_marks']?.toString() ?? '–',
        'Extractor Marks': ballistic['extractor_marks']?.toString() ?? '–',
        'Chamber Marks': ballistic['chamber_marks']?.toString() ?? '–',
        'Test Date': _fmtDate(ballistic['test_date']?.toString()),
        'Forensic Lab': ballistic['forensic_lab']?.toString() ?? '–',
        'Verified': (ballistic['is_locked'] == true &&
                ballistic['registration_hash'] != null)
            ? 'Yes'
            : 'No',
      }));
    }

    return widgets;
  }

  // ─────────────────────────────────────────────
  // BALLISTIC SUMMARY
  // ─────────────────────────────────────────────
  static List<pw.Widget> _ballisticSummary(Map<String, dynamic> data) {
    final profiles = _asList(data['profiles']);
    if (profiles.isEmpty) {
      return [
        _sectionTitle('Ballistic Profiles'),
        _emptyNote('No ballistic profiles found.')
      ];
    }
    final widgets = <pw.Widget>[_sectionTitle('Ballistic Reference Profiles')];
    for (final p in profiles) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Firearm: ${p['serial_number'] ?? 'N/A'} — ${p['firearm_type'] ?? ''} — ${p['caliber'] ?? ''}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            _keyValueGrid({
              'Rifling': p['rifling_characteristics']?.toString() ?? '–',
              'Firing Pin': p['firing_pin_impression']?.toString() ?? '–',
              'Ejector Marks': p['ejector_marks']?.toString() ?? '–',
              'Extractor Marks': p['extractor_marks']?.toString() ?? '–',
              'Chamber Marks': p['chamber_marks']?.toString() ?? '–',
              'Forensic Lab': p['forensic_lab']?.toString() ?? '–',
              'Test Date': _fmtDate(p['test_date']?.toString()),
              'Verified':
                  (p['is_locked'] == true && p['registration_hash'] != null)
                      ? 'Yes'
                      : 'No',
            }),
          ],
        ),
      ));
    }
    return widgets;
  }

  // ─────────────────────────────────────────────
  // ANOMALY SUMMARY
  // ─────────────────────────────────────────────
  static List<pw.Widget> _anomalySummary(Map<String, dynamic> data) {
    final anomalies = _asList(data['anomalies']);
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final widgets = <pw.Widget>[_sectionTitle('Anomaly Detection Summary')];

    // Summary stats
    if (summary.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          _statBox('Total', summary['total']?.toString() ?? '0'),
          _statBox('High/Critical', summary['high']?.toString() ?? '0'),
          _statBox('Medium', summary['medium']?.toString() ?? '0'),
          _statBox('Low', summary['low']?.toString() ?? '0'),
          if (summary['reviewed'] != null)
            _statBox('Reviewed', summary['reviewed'].toString()),
          if (summary['pending'] != null)
            _statBox('Pending', summary['pending'].toString()),
        ],
      ));
    }

    if (anomalies.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 12));
      widgets.add(_table(
        headers: [
          'Anomaly ID',
          'Firearm Serial',
          'Unit',
          'Severity',
          'Status',
          'Detected'
        ],
        rows: anomalies
            .map((a) => [
                  a['anomaly_id']?.toString() ?? '',
                  a['serial_number']?.toString() ?? '–',
                  a['unit_name']?.toString() ?? '–',
                  a['severity']?.toString() ?? '',
                  a['status']?.toString() ?? '',
                  _fmtDate(a['detected_at']?.toString()),
                ])
            .toList(),
      ));
    }
    return widgets;
  }

  // ─────────────────────────────────────────────
  // USER ACTIVITY (Admin)
  // ─────────────────────────────────────────────
  static List<pw.Widget> _userActivity(Map<String, dynamic> data) {
    final activities = _asList(data['activities']);
    if (activities.isEmpty) {
      return [
        _sectionTitle('User Activity'),
        _emptyNote('No user activity found.')
      ];
    }
    return [
      _sectionTitle('User Activity Audit'),
      _table(
        headers: ['Username', 'Role', 'Action', 'Record', 'Date & Time'],
        rows: activities
            .map((a) => [
                  a['username']?.toString() ?? '',
                  a['role']?.toString() ?? '',
                  a['action_type']?.toString() ?? '',
                  '${a['table_name'] ?? ''} ${a['record_id'] ?? ''}'.trim(),
                  _fmtDateTime(a['created_at']?.toString()),
                ])
            .toList(),
      ),
    ];
  }

  // ─────────────────────────────────────────────
  // AUDIT LOG (Admin)
  // ─────────────────────────────────────────────
  static List<pw.Widget> _auditLog(Map<String, dynamic> data) {
    final logs = _asList(data['audit_logs']);
    if (logs.isEmpty) {
      return [
        _sectionTitle('Audit Log'),
        _emptyNote('No audit log entries found.')
      ];
    }
    return [
      _sectionTitle('System Audit Trail'),
      _table(
        headers: ['Event Type', 'Performed By', 'Date & Time', 'Status'],
        rows: logs
            .map((l) => [
                  l['action_type']?.toString() ?? '',
                  l['actor_name']?.toString() ??
                      l['username']?.toString() ??
                      '',
                  _fmtDateTime(l['created_at']?.toString()),
                  l['success'] == true ? 'Success' : 'Failed',
                ])
            .toList(),
      ),
    ];
  }

  // ─────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _primaryColor,
        ),
      ),
    );
  }

  static pw.Widget _emptyNote(String message) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      child: pw.Text(
        message,
        style: pw.TextStyle(
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey600),
      ),
    );
  }

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
          fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFF252A3A)),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      headers: headers,
      data: rows,
    );
  }

  static pw.Widget _keyValueGrid(Map<String, String> fields) {
    final entries = fields.entries.toList();
    final rows = <pw.TableRow>[];
    for (int i = 0; i < entries.length; i += 2) {
      rows.add(pw.TableRow(children: [
        _kvCell(entries[i].key, entries[i].value),
        if (i + 1 < entries.length)
          _kvCell(entries[i + 1].key, entries[i + 1].value)
        else
          pw.SizedBox(),
      ]));
    }
    return pw.Table(children: rows);
  }

  static pw.Widget _kvCell(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(
            text: '$label: ',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ]),
      ),
    );
  }

  static pw.Widget _statBox(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(right: 12),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) return List<Map<String, dynamic>>.from(value);
    return [];
  }

  static String _fmtDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '–';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  static String _fmtDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '–';
    try {
      return DateFormat('MMM d, yyyy – h:mm a').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}
