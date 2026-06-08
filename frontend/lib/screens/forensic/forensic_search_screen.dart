// Forensic Investigation Search
// Professional ballistic profile search with custody timeline integration
// Clean, minimal interface for law enforcement investigators

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ballistic_profile_provider.dart';
import '../../services/forensic_traceability_service.dart';
import '../../utils/pdf_report_generator.dart';
import '../../widgets/custody_timeline_widget.dart';

enum _ResultLayout { full, compact, stacked }

class _BallisticTrait {
  final String label;
  final String matchKey;
  final String? value;

  const _BallisticTrait({
    required this.label,
    required this.matchKey,
    required this.value,
  });
}

class _BallisticSummary {
  final String primaryText;
  final int remainingCount;

  const _BallisticSummary({
    required this.primaryText,
    required this.remainingCount,
  });

  String get displayText =>
      remainingCount > 0 ? '$primaryText +$remainingCount more' : primaryText;
}

class ForensicSearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialSearchResults;
  final int? initialTotalResults;
  final int initialCurrentPage;
  final int? initialTotalPages;
  final String? initialIncidentDate;

  const ForensicSearchScreen({
    super.key,
    this.initialSearchResults = const [],
    this.initialTotalResults,
    this.initialCurrentPage = 1,
    this.initialTotalPages,
    this.initialIncidentDate,
  });

  @override
  State<ForensicSearchScreen> createState() => _ForensicSearchScreenState();
}

class _ForensicSearchScreenState extends State<ForensicSearchScreen> {
  // Search controllers — based on evidence characteristics found at crime scene
  final TextEditingController _generalSearchController =
      TextEditingController();
  final TextEditingController _firingPinController = TextEditingController();
  final TextEditingController _caliberController = TextEditingController();
  final TextEditingController _riflingController = TextEditingController();
  final TextEditingController _chamberFeedController = TextEditingController();
  final TextEditingController _breechFaceController = TextEditingController();
  final TextEditingController _testLocationController = TextEditingController();

  // Investigation context
  final TextEditingController _incidentDateController = TextEditingController();

  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _errorMessage;

  // Pagination state
  int _currentPage = 1;
  int _totalResults = 0;
  int _totalPages = 0;
  static const int _resultsPerPage = 20;

  // Custody timeline state
  String? _selectedFirearmId;
  String? _selectedFirearmLabel;
  bool _isLoadingTimeline = false;
  List<Map<String, dynamic>> _custodyTimeline = [];
  Map<String, dynamic>? _custodySummary;
  String? _timelineError;

  final ForensicTraceabilityService _traceabilityService =
      ForensicTraceabilityService();

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchResults.isNotEmpty) {
      _searchResults = List<Map<String, dynamic>>.from(
        widget.initialSearchResults,
      );
      _totalResults = widget.initialTotalResults ?? _searchResults.length;
      _currentPage = widget.initialCurrentPage;
      _totalPages = widget.initialTotalPages ??
          (_totalResults / _resultsPerPage).ceil().clamp(1, 999999).toInt();
    }
    if (widget.initialIncidentDate != null) {
      _incidentDateController.text = widget.initialIncidentDate!;
    }
  }

  @override
  void dispose() {
    _generalSearchController.dispose();
    _firingPinController.dispose();
    _caliberController.dispose();
    _riflingController.dispose();
    _chamberFeedController.dispose();
    _breechFaceController.dispose();
    _testLocationController.dispose();
    _incidentDateController.dispose();
    super.dispose();
  }

  bool get _hasAnyFilter {
    return _generalSearchController.text.isNotEmpty ||
        _firingPinController.text.isNotEmpty ||
        _caliberController.text.isNotEmpty ||
        _riflingController.text.isNotEmpty ||
        _chamberFeedController.text.isNotEmpty ||
        _breechFaceController.text.isNotEmpty ||
        _testLocationController.text.isNotEmpty ||
        _incidentDateController.text.isNotEmpty;
  }

  void _clearAllFilters() {
    setState(() {
      _generalSearchController.clear();
      _firingPinController.clear();
      _caliberController.clear();
      _riflingController.clear();
      _chamberFeedController.clear();
      _breechFaceController.clear();
      _testLocationController.clear();
      _searchResults = [];
      _errorMessage = null;
      _selectedFirearmId = null;
      _selectedFirearmLabel = null;
      _custodyTimeline = [];
      _custodySummary = null;
      _timelineError = null;
      _currentPage = 1;
      _totalResults = 0;
      _totalPages = 0;
      _incidentDateController.clear();
    });
  }

  Future<void> _exportPdf() async {
    if (_searchResults.isEmpty) return;

    try {
      final metadata = <String, String>{};
      if (_incidentDateController.text.isNotEmpty) {
        metadata['Incident Date'] = _incidentDateController.text;
      }
      if (_generalSearchController.text.isNotEmpty) {
        metadata['General Search'] = _generalSearchController.text;
      }
      if (_caliberController.text.isNotEmpty) {
        metadata['Caliber'] = _caliberController.text;
      }
      if (_firingPinController.text.isNotEmpty) {
        metadata['Firing Pin'] = _firingPinController.text;
      }
      if (_riflingController.text.isNotEmpty) {
        metadata['Rifling'] = _riflingController.text;
      }
      if (_chamberFeedController.text.isNotEmpty) {
        metadata['Chamber Feed'] = _chamberFeedController.text;
      }
      if (_breechFaceController.text.isNotEmpty) {
        metadata['Breech Face'] = _breechFaceController.text;
      }
      if (_testLocationController.text.isNotEmpty) {
        metadata['Test Location'] = _testLocationController.text;
      }

      await PdfReportGenerator.generate(
        reportTitle: 'Forensic Investigation Search Results',
        reportType: 'ballistic_summary',
        reportData: {'profiles': _searchResults},
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

  Future<void> _exportCustodyPdf() async {
    if (_selectedFirearmId == null || _custodyTimeline.isEmpty) return;

    try {
      final metadata = <String, String>{
        'Firearm': _selectedFirearmLabel ?? 'Unknown',
      };
      if (_incidentDateController.text.isNotEmpty) {
        metadata['Incident Date'] = _incidentDateController.text;
      }

      await PdfReportGenerator.generate(
        reportTitle: 'Firearm Custody Timeline',
        reportType: 'firearm_history',
        reportData: {
          'firearms': [
            {
              'serial_number': _selectedFirearmLabel,
            }
          ],
          'custody_records': _custodyTimeline
              .map((record) => {
                    'serial_number': _selectedFirearmLabel,
                    'officer_name':
                        record['officer_name'] ?? record['officer_id'] ?? '',
                    'officer_rank': record['officer_rank'] ?? '',
                    'unit_name': record['unit_name'] ?? '',
                    'issued_at': record['issued_at'],
                    'returned_at': record['returned_at'],
                    'duration': record['duration'] ?? '-',
                    'custody_type': record['custody_type'] ?? '',
                  })
              .toList(),
          'anomalies': [],
          'ballistic_profile': null,
        },
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

  Future<void> _performSearch({int page = 1}) async {
    if (!_hasAnyFilter) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter at least one search criterion'),
          backgroundColor: const Color(0xFF37404F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _selectedFirearmId = null;
      _custodyTimeline = [];
    });

    try {
      final provider = Provider.of<BallisticProfileProvider>(
        context,
        listen: false,
      );

      final response = await provider.forensicSearch(
        firingPin: _firingPinController.text.trim().isNotEmpty
            ? _firingPinController.text.trim()
            : null,
        caliber: _caliberController.text.trim().isNotEmpty
            ? _caliberController.text.trim()
            : null,
        rifling: _riflingController.text.trim().isNotEmpty
            ? _riflingController.text.trim()
            : null,
        chamberFeed: _chamberFeedController.text.trim().isNotEmpty
            ? _chamberFeedController.text.trim()
            : null,
        breechFace: _breechFaceController.text.trim().isNotEmpty
            ? _breechFaceController.text.trim()
            : null,
        testLocation: _testLocationController.text.trim().isNotEmpty
            ? _testLocationController.text.trim()
            : null,
        generalSearch: _generalSearchController.text.trim().isNotEmpty
            ? _generalSearchController.text.trim()
            : null,
        incidentDate: _incidentDateController.text.trim().isNotEmpty
            ? _incidentDateController.text.trim()
            : null,
        incidentDateMode: 'annotate',
        page: page,
        limit: _resultsPerPage,
      );

      setState(() {
        _searchResults =
            List<Map<String, dynamic>>.from(response['data'] ?? []);
        _totalResults = response['total'] ?? 0;
        _currentPage = response['page'] ?? 1;
        _totalPages = response['totalPages'] ?? 0;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSearching = false;
      });
    }
  }

  Future<void> _loadCustodyTimeline(
      String firearmId, String firearmLabel) async {
    setState(() {
      _selectedFirearmId = firearmId;
      _selectedFirearmLabel = firearmLabel;
      _isLoadingTimeline = true;
      _timelineError = null;
    });

    try {
      final response = await _traceabilityService.getCustodyTimeline(firearmId);
      final timelineData = response['timeline'];
      setState(() {
        _custodyTimeline = timelineData is List
            ? List<Map<String, dynamic>>.from(timelineData)
            : [];
        _custodySummary = response['summary'] as Map<String, dynamic>?;
        _isLoadingTimeline = false;
      });
    } catch (e) {
      setState(() {
        _timelineError = 'Unable to load custody timeline';
        _isLoadingTimeline = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSearchPanel(),
          const SizedBox(height: 24),
          _buildResultsSection(),
          if (_selectedFirearmId != null) ...[
            const SizedBox(height: 24),
            _buildCustodyTimelinePanel(),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Investigation Search',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Enter crime-scene evidence traits, narrow candidate weapons, then reconstruct custody at incident time',
                style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox.shrink(),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SEARCH PANEL
  // ─────────────────────────────────────────────

  Widget _buildSearchPanel() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF232838),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E3546)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'INVESTIGATION SEARCH CRITERIA',
              style: TextStyle(
                color: Color(0xFFCFD8DC),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 720;
                final fieldWidth = isNarrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _buildField(
                        controller: _generalSearchController,
                        label: 'General Search',
                        prefixIcon: Icons.search,
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _buildField(
                        controller: _incidentDateController,
                        label: 'Incident Date',
                        isDateField: true,
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _buildDropdownField(
                        controller: _caliberController,
                        label: 'Caliber / Ammunition',
                        items: [
                          '9x19mm Parabellum',
                          '7.62x39mm',
                          '5.56x45mm NATO',
                          '7.62x51mm NATO',
                          '12 Gauge',
                          '.45 ACP'
                        ],
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _buildField(
                        controller: _firingPinController,
                        label: 'Firing Pin Impression',
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _buildDropdownField(
                        controller: _riflingController,
                        label: 'Rifling Characteristics',
                        items: [
                          '4 grooves, right-hand twist, 1:9.5 pitch',
                          '6 grooves, right-hand twist, 1:10 pitch',
                          '6 grooves, right-hand twist, 1:7 pitch',
                          '4 grooves, right-hand twist, 1:16 pitch',
                          'Smoothbore'
                        ],
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _buildField(
                        controller: _chamberFeedController,
                        label: 'Chamber / Feed Marks',
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _buildField(
                        controller: _breechFaceController,
                        label: 'Breech Face (Ejector / Extractor)',
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _buildField(
                        controller: _testLocationController,
                        label: 'Recovery Location',
                        prefixIcon: Icons.location_on_outlined,
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            ' ',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        _hasAnyFilter ? _clearAllFilters : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFCFD8DC),
                                      side: const BorderSide(
                                          color: Color(0xFF455A64)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    child: const Text('Clear All',
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _searchResults.isNotEmpty
                                        ? _exportPdf
                                        : null,
                                    icon: const Icon(Icons.picture_as_pdf,
                                        size: 18),
                                    label: const Text('Export PDF',
                                        overflow: TextOverflow.ellipsis),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                          color: _searchResults.isNotEmpty
                                              ? const Color(0xFF1E88E5)
                                              : const Color(0xFF455A64)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed:
                                        _isSearching ? null : _performSearch,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E88E5),
                                      disabledBackgroundColor:
                                          const Color(0xFF1E88E5)
                                              .withValues(alpha: 0.5),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    child: _isSearching
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Search',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool isDateField = false,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCFD8DC),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: isDateField
              ? _buildDateTextField(controller: controller)
              : TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: prefixIcon == null
                        ? null
                        : Icon(
                            prefixIcon,
                            color: const Color(0xFF78909C),
                            size: 20,
                          ),
                    filled: true,
                    fillColor: const Color(0xFF2A3040),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
                      borderSide: const BorderSide(
                        color: Color(0xFF1E88E5),
                        width: 2,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCFD8DC),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: Autocomplete<String>(
            initialValue: TextEditingValue(text: controller.text),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return items;
              }
              return items.where((String option) {
                return option
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              controller.text = selection;
              _performSearch();
            },
            fieldViewBuilder:
                (context, txtController, focusNode, onFieldSubmitted) {
              txtController.addListener(() {
                controller.text = txtController.text;
              });
              return TextField(
                controller: txtController,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.arrow_drop_down,
                      color: Color(0xFF78909C)),
                  filled: true,
                  fillColor: const Color(0xFF2A3040),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
                    borderSide:
                        const BorderSide(color: Color(0xFF1E88E5), width: 2),
                  ),
                ),
                onSubmitted: (_) {
                  onFieldSubmitted();
                  _performSearch();
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Material(
                    elevation: 4.0,
                    color: const Color(0xFF2A3040),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF37404F)),
                    ),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxHeight: 200, maxWidth: 300),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Text(option,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateTextField({
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      readOnly: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF2A3040),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        suffixIcon: const Icon(Icons.calendar_today,
            color: Color(0xFF546E7A), size: 16),
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
          borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
        ),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
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
                  todayBackgroundColor:
                      WidgetStateProperty.all(Colors.transparent),
                  todayBorder: const BorderSide(color: Color(0xFF42A5F5)),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          controller.text =
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        }
      },
    );
  }

  // ─────────────────────────────────────────────
  // RESULTS SECTION
  // ─────────────────────────────────────────────

  Widget _buildResultsSection() {
    if (_errorMessage != null) return _buildErrorState();
    if (_isSearching) return _buildLoadingState();
    if (_searchResults.isEmpty && !_hasAnyFilter) return _buildEmptyState();
    if (_searchResults.isEmpty && _hasAnyFilter) return _buildNoResultsState();
    return _buildResultsTable();
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF232838),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFE57373).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE57373), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFE57373), fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _performSearch,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64B5F6),
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: const Color(0xFF232838),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1E88E5),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Searching ballistic profiles...',
              style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
        color: const Color(0xFF232838),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E3546)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search,
                size: 40,
                color: const Color(0xFF546E7A).withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            const Text(
              'Enter evidence characteristics from crime scene to narrow down matching firearms',
              style: TextStyle(
                color: Color(0xFF78909C),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Even 1-2 filters will return results - click any result to trace its custody chain',
              style: TextStyle(color: Color(0xFF455A64), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: const Color(0xFF232838),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 36, color: Color(0xFF546E7A)),
            SizedBox(height: 12),
            Text(
              'No matching ballistic profiles found',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Text(
              'Try adjusting your search criteria or using fewer filters',
              style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // RESULTS TABLE
  // ─────────────────────────────────────────────

  Widget _buildResultsTable() {
    final hasIncidentDate = _incidentDateController.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF232838),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E3546)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResultsHeader(hasIncidentDate),
          const Divider(color: Color(0xFF2E3546), height: 1),

          LayoutBuilder(
            builder: (context, constraints) {
              final layout = _resultLayoutForWidth(constraints.maxWidth);
              return Column(
                children: [
                  if (layout != _ResultLayout.stacked)
                    _buildResultHeaderRow(layout),
                  for (int index = 0; index < _searchResults.length; index++)
                    _buildResultRow(_searchResults[index], index, layout),
                ],
              );
            },
          ),

          // Pagination controls
          if (_totalPages > 1) ...[
            const Divider(color: Color(0xFF2E3546), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${((_currentPage - 1) * _resultsPerPage) + 1}\u2013${_currentPage * _resultsPerPage > _totalResults ? _totalResults : _currentPage * _resultsPerPage} of $_totalResults',
                    style: const TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      // First page
                      _buildPageButton(
                        icon: Icons.first_page,
                        onPressed: _currentPage > 1
                            ? () => _performSearch(page: 1)
                            : null,
                        tooltip: 'First page',
                      ),
                      const SizedBox(width: 4),
                      // Previous page
                      _buildPageButton(
                        icon: Icons.chevron_left,
                        onPressed: _currentPage > 1
                            ? () => _performSearch(page: _currentPage - 1)
                            : null,
                        tooltip: 'Previous page',
                      ),
                      const SizedBox(width: 12),
                      // Page numbers
                      ..._buildPageNumbers(),
                      const SizedBox(width: 12),
                      // Next page
                      _buildPageButton(
                        icon: Icons.chevron_right,
                        onPressed: _currentPage < _totalPages
                            ? () => _performSearch(page: _currentPage + 1)
                            : null,
                        tooltip: 'Next page',
                      ),
                      const SizedBox(width: 4),
                      // Last page
                      _buildPageButton(
                        icon: Icons.last_page,
                        onPressed: _currentPage < _totalPages
                            ? () => _performSearch(page: _totalPages)
                            : null,
                        tooltip: 'Last page',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsHeader(bool hasIncidentDate) {
    final countText =
        '$_totalResults result${_totalResults != 1 ? 's' : ''} found'
        '${_totalPages > 1 ? ' - Page $_currentPage of $_totalPages' : ''}';
    final hintText = hasIncidentDate
        ? 'Incident date annotates custody overlap; click a row for full chain'
        : 'Click a row to view custody chain';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final status = Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  countText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
          final hint = Text(
            hintText,
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
            overflow: TextOverflow.ellipsis,
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                status,
                const SizedBox(height: 6),
                hint,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: status),
              const SizedBox(width: 16),
              Flexible(child: hint),
            ],
          );
        },
      ),
    );
  }

  _ResultLayout _resultLayoutForWidth(double width) {
    if (width >= 1100) return _ResultLayout.full;
    if (width >= 820) return _ResultLayout.compact;
    return _ResultLayout.stacked;
  }

  Widget _buildResultHeaderRow(_ResultLayout layout) {
    final isFull = layout == _ResultLayout.full;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFF1E2333),
      child: Row(
        children: [
          _buildHeaderCell('FIREARM', flex: isFull ? 18 : 20),
          _buildHeaderCell('EVIDENCE', flex: isFull ? 14 : 16),
          _buildHeaderCell('MATCHED TRAITS', flex: isFull ? 14 : 16),
          _buildHeaderCell('INCIDENT CUSTODY', flex: isFull ? 16 : 18),
          _buildHeaderCell('KEY BALLISTICS', flex: isFull ? 18 : 18),
          if (isFull) _buildHeaderCell('DATA INTEGRITY', flex: 14),
          const SizedBox(
            width: 58,
            child: Text('TRACE', style: _columnHeaderStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: _columnHeaderStyle,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildResultRow(
    Map<String, dynamic> profile,
    int index,
    _ResultLayout layout,
  ) {
    final firearmId = profile['firearm_id']?.toString() ?? '';
    final firearmLabel =
        '${profile['manufacturer'] ?? ''} ${profile['model'] ?? ''}'.trim();
    final serial = profile['serial_number']?.toString() ?? 'N/A';
    final isSelected = _selectedFirearmId == firearmId;
    final onTrace = firearmId.isEmpty
        ? null
        : () => _loadCustodyTimeline(firearmId, firearmLabel);
    final rowColor = isSelected
        ? const Color(0xFF1E88E5).withValues(alpha: 0.08)
        : index.isEven
            ? const Color(0xFF232838)
            : const Color(0xFF1E2333);

    return Material(
      color: rowColor,
      child: InkWell(
        onTap: onTrace,
        hoverColor: const Color(0xFF2E3546).withValues(alpha: 0.5),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: layout == _ResultLayout.stacked ? 12 : 14,
            vertical: layout == _ResultLayout.stacked ? 12 : 10,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF2E3546), width: 1),
            ),
          ),
          child: switch (layout) {
            _ResultLayout.full => _buildFullResultRow(
                profile,
                firearmLabel,
                serial,
                isSelected,
                onTrace,
              ),
            _ResultLayout.compact => _buildCompactResultRow(
                profile,
                firearmLabel,
                serial,
                isSelected,
                onTrace,
              ),
            _ResultLayout.stacked => _buildStackedResultRow(
                profile,
                firearmLabel,
                serial,
                isSelected,
                onTrace,
              ),
          },
        ),
      ),
    );
  }

  Widget _buildFullResultRow(
    Map<String, dynamic> profile,
    String firearmLabel,
    String serial,
    bool isSelected,
    VoidCallback? onTrace,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 18,
          child: _buildFirearmSummary(
            firearmLabel,
            serial,
            profile['caliber']?.toString(),
          ),
        ),
        Expanded(flex: 14, child: _buildEvidenceStrengthBadge(profile)),
        Expanded(flex: 14, child: _buildMatchedTraits(profile, maxTraits: 3)),
        Expanded(flex: 16, child: _buildIncidentCustodySummary(profile)),
        Expanded(flex: 18, child: _buildKeyBallistics(profile)),
        Expanded(flex: 14, child: _buildIntegrityBadge(profile)),
        SizedBox(
          width: 58,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildTraceButton(
              isSelected: isSelected,
              onTap: onTrace,
              iconOnly: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactResultRow(
    Map<String, dynamic> profile,
    String firearmLabel,
    String serial,
    bool isSelected,
    VoidCallback? onTrace,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 20,
          child: _buildFirearmSummary(
            firearmLabel,
            serial,
            profile['caliber']?.toString(),
            profile: profile,
          ),
        ),
        Expanded(flex: 16, child: _buildEvidenceStrengthBadge(profile)),
        Expanded(flex: 16, child: _buildMatchedTraits(profile, maxTraits: 2)),
        Expanded(flex: 18, child: _buildIncidentCustodySummary(profile)),
        Expanded(flex: 18, child: _buildKeyBallistics(profile)),
        SizedBox(
          width: 58,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildTraceButton(
              isSelected: isSelected,
              onTap: onTrace,
              iconOnly: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStackedResultRow(
    Map<String, dynamic> profile,
    String firearmLabel,
    String serial,
    bool isSelected,
    VoidCallback? onTrace,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFirearmSummary(
                firearmLabel,
                serial,
                profile['caliber']?.toString(),
              ),
            ),
            const SizedBox(width: 8),
            _buildTraceButton(
              isSelected: isSelected,
              onTap: onTrace,
              iconOnly: true,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMetadataChip('EVIDENCE', _evidenceStrengthText(profile)),
            _buildMetadataChip('MATCHED', _matchedTraitsText(profile)),
            _buildMetadataChip(
              'INCIDENT CUSTODY',
              _incidentCustodyText(profile),
            ),
            _buildMetadataChip(
              'KEY BALLISTICS',
              _ballisticSummary(profile).displayText,
            ),
            _buildMetadataChip('INTEGRITY', _integrityText(profile)),
          ],
        ),
      ],
    );
  }

  Widget _buildFirearmSummary(
    String firearmLabel,
    String serial,
    String? caliber, {
    Map<String, dynamic>? profile,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ellipsizedText(
          firearmLabel.isNotEmpty ? firearmLabel : 'N/A',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        _ellipsizedText(
          serial,
          style: const TextStyle(
            color: Color(0xFF64B5F6),
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
        _ellipsizedText(
          caliber ?? '-',
          style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
        ),
        if (profile != null) ...[
          const SizedBox(height: 3),
          _buildIntegrityInline(profile),
        ],
      ],
    );
  }

  Widget _ellipsizedText(
    String text, {
    required TextStyle style,
    int maxLines = 1,
  }) {
    return Tooltip(
      message: text,
      waitDuration: const Duration(milliseconds: 500),
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  Widget _buildMetadataChip(String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF37404F)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _columnHeaderStyle),
            const SizedBox(height: 3),
            _ellipsizedText(
              value,
              style: const TextStyle(
                color: Color(0xFFCFD8DC),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _evidenceStrengthText(Map<String, dynamic> profile) {
    final strength =
        profile['evidence_strength']?.toString() ?? 'Reference match';
    final score = int.tryParse(profile['match_score']?.toString() ?? '0') ?? 0;
    return '$strength - score $score';
  }

  String _matchedTraitsText(Map<String, dynamic> profile) {
    final traits = _matchedTraits(profile);
    if (traits.isEmpty) return 'Reference profile';
    final shown = traits.take(2).join(', ');
    final remaining = traits.length - 2;
    return remaining > 0 ? '$shown +$remaining more' : shown;
  }

  String _incidentCustodyText(Map<String, dynamic> profile) {
    final hasIncidentDate = _incidentDateController.text.trim().isNotEmpty;
    if (!hasIncidentDate) return 'No incident date';

    final custody = profile['incident_custody'];
    final custodyMap = custody is Map ? custody : const {};
    final heldAtIncident = custodyMap['held_at_incident'] == true;
    if (!heldAtIncident) return 'No custody overlap';

    final officer = custodyMap['officer_name']?.toString();
    return officer == null || officer.isEmpty ? 'Held at incident' : officer;
  }

  String _integrityText(Map<String, dynamic> profile) {
    final isLocked = profile['is_locked'] == true;
    final hash = profile['registration_hash']?.toString();
    final hasHash = hash != null && hash.isNotEmpty;
    if (!isLocked || !hasHash) return 'Unverified record';
    final shortHash = hash.length > 8 ? hash.substring(0, 8) : hash;
    return 'Sealed - Hash $shortHash';
  }

  List<String> _matchedTraits(Map<String, dynamic> profile) {
    final raw = profile['matched_fields'];
    return raw is List
        ? raw
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
  }

  Widget _buildIntegrityInline(Map<String, dynamic> profile) {
    final verified = profile['is_locked'] == true &&
        profile['registration_hash'] != null &&
        profile['registration_hash'].toString().isNotEmpty;
    final color = verified ? const Color(0xFF81C784) : const Color(0xFFFFB74D);
    return Row(
      children: [
        Icon(
          verified ? Icons.verified_user : Icons.warning_amber_rounded,
          color: color,
          size: 12,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _ellipsizedText(
            verified ? 'Sealed profile' : 'Unverified record',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvidenceStrengthBadge(Map<String, dynamic> profile) {
    final strength =
        profile['evidence_strength']?.toString() ?? 'Reference match';
    final score = int.tryParse(profile['match_score']?.toString() ?? '0') ?? 0;
    final color = switch (strength) {
      'Strong candidate' => const Color(0xFFFFA726),
      'Partial candidate' => const Color(0xFF64B5F6),
      _ => const Color(0xFF90A4AE),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ellipsizedText(
            strength,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          _ellipsizedText(
            'Evidence score $score',
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedTraits(
    Map<String, dynamic> profile, {
    int maxTraits = 4,
  }) {
    final traits = _matchedTraits(profile);
    if (traits.isEmpty) {
      return const Text(
        'Reference profile',
        style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
      );
    }

    final visibleTraits = traits.take(maxTraits).toList();
    final remaining = traits.length - visibleTraits.length;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...visibleTraits.map(_buildTraitChip),
        if (remaining > 0) _buildTraitChip('+$remaining more'),
      ],
    );
  }

  Widget _buildTraitChip(String trait) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF1E88E5).withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        trait,
        style: const TextStyle(
          color: Color(0xFF90CAF9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildIncidentCustodySummary(Map<String, dynamic> profile) {
    final custody = profile['incident_custody'];
    final hasIncidentDate = _incidentDateController.text.trim().isNotEmpty;
    final custodyMap = custody is Map ? custody : const {};
    final heldAtIncident = custodyMap['held_at_incident'] == true;

    if (!hasIncidentDate) {
      return const Text(
        'No incident date entered',
        style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final color =
        heldAtIncident ? const Color(0xFFFFA726) : const Color(0xFF78909C);
    final label = heldAtIncident ? 'Held at incident' : 'No custody overlap';
    final officer = custodyMap['officer_name']?.toString();
    final unit = custodyMap['unit_name']?.toString();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              heldAtIncident ? Icons.priority_high : Icons.info_outline,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (heldAtIncident) ...[
          const SizedBox(height: 3),
          _ellipsizedText(
            officer ?? 'Unknown officer',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          _ellipsizedText(
            unit ?? 'Unknown unit',
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildKeyBallistics(Map<String, dynamic> profile) {
    final summary = _ballisticSummary(profile);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ellipsizedText(
          summary.primaryText,
          style: const TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (summary.remainingCount > 0) ...[
          const SizedBox(height: 3),
          Text(
            '+${summary.remainingCount} more',
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  _BallisticSummary _ballisticSummary(Map<String, dynamic> profile) {
    final matched =
        _matchedTraits(profile).map((trait) => trait.toLowerCase()).toSet();
    final candidates = <_BallisticTrait>[
      _BallisticTrait(
        label: 'Pin',
        matchKey: 'firing pin',
        value: profile['firing_pin_impression']?.toString(),
      ),
      _BallisticTrait(
        label: 'Rifling',
        matchKey: 'rifling',
        value: profile['rifling_characteristics']?.toString(),
      ),
      _BallisticTrait(
        label: 'Chamber',
        matchKey: 'chamber/feed',
        value: profile['chamber_marks']?.toString(),
      ),
      _BallisticTrait(
        label: 'Breech',
        matchKey: 'breech face',
        value: _combineBreechFace(
          profile['ejector_marks']?.toString(),
          profile['extractor_marks']?.toString(),
        ),
      ),
      _BallisticTrait(
        label: 'Caliber',
        matchKey: 'caliber',
        value: profile['caliber']?.toString(),
      ),
    ];

    final useful = candidates
        .where((trait) => _isUsefulProfileValue(trait.value))
        .toList();
    if (useful.isEmpty) {
      return const _BallisticSummary(
        primaryText: 'No ballistic trait',
        remainingCount: 0,
      );
    }

    final matchedTrait = useful.cast<_BallisticTrait?>().firstWhere(
          (trait) => matched.contains(trait!.matchKey),
          orElse: () => null,
        );
    final primary = matchedTrait ?? useful.first;
    return _BallisticSummary(
      primaryText: '${primary.label}: ${primary.value}',
      remainingCount: useful.length - 1,
    );
  }

  bool _isUsefulProfileValue(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty &&
        normalized != 'null' &&
        normalized != '-' &&
        normalized != 'n/a';
  }

  Widget _buildIntegrityBadge(Map<String, dynamic> profile) {
    final isLocked = profile['is_locked'] == true;
    final hash = profile['registration_hash']?.toString();
    final hasHash = hash != null && hash.isNotEmpty;
    if (!isLocked || !hasHash) {
      return const Text(
        'Unverified record',
        style: TextStyle(color: Color(0xFFFFB74D), fontSize: 12),
      );
    }

    final shortHash = hash.length > 8 ? hash.substring(0, 8) : hash;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.verified_user, color: Color(0xFF4CAF50), size: 13),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Sealed profile',
                style: TextStyle(
                  color: Color(0xFF81C784),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        _ellipsizedText(
          'Hash $shortHash',
          style: const TextStyle(
            color: Color(0xFFCFD8DC),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildTraceButton({
    required bool isSelected,
    required VoidCallback? onTap,
    bool iconOnly = false,
  }) {
    final color =
        isSelected ? const Color(0xFF64B5F6) : const Color(0xFF78909C);
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: iconOnly ? 36 : null,
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E88E5).withValues(alpha: 0.15)
              : const Color(0xFF1E88E5).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 15, color: color),
            if (!iconOnly) ...[
              const SizedBox(width: 4),
              Text(
                'Trace',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Tooltip(
      message: 'Trace custody chain',
      child: button,
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    VoidCallback? onPressed,
    required String tooltip,
  }) {
    final isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isEnabled
                ? const Color(0xFF1A1F2E)
                : const Color(0xFF1A1F2E).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEnabled
                  ? const Color(0xFF2E3546)
                  : const Color(0xFF2E3546).withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isEnabled
                ? const Color(0xFFB0BEC5)
                : const Color(0xFF546E7A).withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    final List<Widget> pages = [];
    final int startPage;
    final int endPage;

    if (_totalPages <= 5) {
      startPage = 1;
      endPage = _totalPages;
    } else if (_currentPage <= 3) {
      startPage = 1;
      endPage = 5;
    } else if (_currentPage >= _totalPages - 2) {
      startPage = _totalPages - 4;
      endPage = _totalPages;
    } else {
      startPage = _currentPage - 2;
      endPage = _currentPage + 2;
    }

    if (startPage > 1) {
      pages.add(_buildPageNumberButton(1));
      if (startPage > 2) {
        pages.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('\u2026', style: TextStyle(color: Color(0xFF546E7A))),
        ));
      }
    }

    for (int i = startPage; i <= endPage; i++) {
      pages.add(_buildPageNumberButton(i));
    }

    if (endPage < _totalPages) {
      if (endPage < _totalPages - 1) {
        pages.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('\u2026', style: TextStyle(color: Color(0xFF546E7A))),
        ));
      }
      pages.add(_buildPageNumberButton(_totalPages));
    }

    return pages;
  }

  Widget _buildPageNumberButton(int page) {
    final isCurrent = page == _currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: isCurrent ? null : () => _performSearch(page: page),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isCurrent ? const Color(0xFF1E88E5) : const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isCurrent ? const Color(0xFF1E88E5) : const Color(0xFF2E3546),
            ),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              color: isCurrent ? Colors.white : const Color(0xFFB0BEC5),
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  static const TextStyle _columnHeaderStyle = TextStyle(
    color: Color(0xFFB0BEC5),
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  String? _combineBreechFace(String? ejector, String? extractor) {
    final parts = <String>[];
    if (ejector != null && ejector.isNotEmpty && ejector != 'null') {
      parts.add(ejector);
    }
    if (extractor != null && extractor.isNotEmpty && extractor != 'null') {
      parts.add(extractor);
    }
    return parts.isNotEmpty ? parts.join(' / ') : null;
  }

  // ─────────────────────────────────────────────
  // CUSTODY TIMELINE PANEL
  // ─────────────────────────────────────────────

  Widget _buildCustodyTimelinePanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF232838),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF1E88E5).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF2E3546)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.timeline,
                      color: Color(0xFF64B5F6), size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custody Chain of Evidence',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedFirearmLabel ?? 'Selected firearm',
                        style: const TextStyle(
                          color: Color(0xFF64B5F6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_custodySummary != null) ...[
                  _buildSummaryChip(
                    'Transfers',
                    _custodySummary!['total_transfers']?.toString() ?? '0',
                  ),
                  const SizedBox(width: 8),
                  _buildSummaryChip(
                    'Current Holder',
                    _custodySummary!['current_holder']?.toString() ?? 'Unknown',
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedFirearmId = null;
                      _custodyTimeline = [];
                      _custodySummary = null;
                    });
                  },
                  icon: const Icon(Icons.close,
                      color: Color(0xFF546E7A), size: 18),
                  splashRadius: 18,
                  tooltip: 'Close timeline',
                ),
              ],
            ),
          ),

          // Incident date context bar
          if (_incidentDateController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFFFFA726).withValues(alpha: 0.06),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFFFFA726), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Incident date: ${_incidentDateController.text}  \u2014  Review the timeline below to determine who held this firearm at the time of the incident.',
                      style: const TextStyle(
                        color: Color(0xFFFFA726),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Timeline content
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildTimelineContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E3546)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineContent() {
    if (_isLoadingTimeline) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1E88E5),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Loading custody chain...',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_timelineError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFE57373), size: 24),
              const SizedBox(height: 8),
              Text(
                _timelineError!,
                style: const TextStyle(color: Color(0xFFE57373), fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _loadCustodyTimeline(
                    _selectedFirearmId!, _selectedFirearmLabel ?? ''),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_custodyTimeline.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(Icons.timeline, color: Color(0xFF455A64), size: 32),
              SizedBox(height: 12),
              Text(
                'No custody records found for this firearm',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustodyTimelineWidget(
          timeline: _custodyTimeline,
          incidentDate: _incidentDateController.text.isNotEmpty
              ? _incidentDateController.text
              : null,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _exportCustodyPdf,
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Export PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF1E88E5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
