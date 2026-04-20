// Forensic Investigation Search
// Professional ballistic profile search with custody timeline integration
// Clean, minimal interface for law enforcement investigators

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ballistic_profile_provider.dart';
import '../../services/forensic_traceability_service.dart';
import '../../utils/pdf_report_generator.dart';
import '../../widgets/custody_timeline_widget.dart';

class ForensicSearchScreen extends StatefulWidget {
  const ForensicSearchScreen({super.key});

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
      if (_incidentDateController.text.isNotEmpty) metadata['Incident Date'] = _incidentDateController.text;
      if (_generalSearchController.text.isNotEmpty) metadata['General Search'] = _generalSearchController.text;
      if (_caliberController.text.isNotEmpty) metadata['Caliber'] = _caliberController.text;
      if (_firingPinController.text.isNotEmpty) metadata['Firing Pin'] = _firingPinController.text;
      if (_riflingController.text.isNotEmpty) metadata['Rifling'] = _riflingController.text;
      if (_chamberFeedController.text.isNotEmpty) metadata['Chamber Feed'] = _chamberFeedController.text;
      if (_breechFaceController.text.isNotEmpty) metadata['Breech Face'] = _breechFaceController.text;
      if (_testLocationController.text.isNotEmpty) metadata['Test Location'] = _testLocationController.text;

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
          'custody_records': _custodyTimeline.map((record) => {
            'serial_number': _selectedFirearmLabel,
            'officer_name': record['officer_name'] ?? record['officer_id'] ?? '',
            'officer_rank': record['officer_rank'] ?? '',
            'unit_name': record['unit_name'] ?? '',
            'issued_at': record['issued_at'],
            'returned_at': record['returned_at'],
            'duration': record['duration'] ?? '-',
            'custody_type': record['custody_type'] ?? '',
          }).toList(),
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
            const Row(
              children: [
                Text(
                  'INVESTIGATION SEARCH CRITERIA',
                  style: TextStyle(
                    color: Color(0xFFCFD8DC),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
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
                      child: _buildField(
                        controller: _caliberController,
                        label: 'Caliber / Ammunition',
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
                      child: _buildField(
                        controller: _riflingController,
                        label: 'Rifling Characteristics',
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
                                    onPressed: _hasAnyFilter ? _clearAllFilters : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFCFD8DC),
                                      side: const BorderSide(color: Color(0xFF455A64)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    child: const Text('Clear All', overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _searchResults.isNotEmpty ? _exportPdf : null,
                                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                                    label: const Text('Export PDF', overflow: TextOverflow.ellipsis),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                          color: _searchResults.isNotEmpty
                                              ? const Color(0xFF1E88E5)
                                              : const Color(0xFF455A64)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isSearching ? null : _performSearch,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E88E5),
                                      disabledBackgroundColor:
                                          const Color(0xFF1E88E5).withValues(alpha: 0.5),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
              'Even 1-2 filters will return results — click any result to trace its custody chain',
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF232838),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E3546)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Results header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
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
                Text(
                  '$_totalResults result${_totalResults != 1 ? 's' : ''} found${_totalPages > 1 ? '  \u2022  Page $_currentPage of $_totalPages' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Click a row to view custody chain',
                  style: TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2E3546), height: 1),

          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1E2333)),
              headingRowHeight: 44,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 56,
              columnSpacing: 24,
              horizontalMargin: 20,
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('FIREARM', style: _columnHeaderStyle)),
                DataColumn(
                    label: Text('SERIAL NO.', style: _columnHeaderStyle)),
                DataColumn(label: Text('CALIBER', style: _columnHeaderStyle)),
                DataColumn(
                    label: Text('FIRING PIN', style: _columnHeaderStyle)),
                DataColumn(label: Text('RIFLING', style: _columnHeaderStyle)),
                DataColumn(label: Text('CHAMBER', style: _columnHeaderStyle)),
                DataColumn(
                    label: Text('BREECH FACE', style: _columnHeaderStyle)),
                DataColumn(label: Text('UNIT', style: _columnHeaderStyle)),
                DataColumn(label: Text('STATUS', style: _columnHeaderStyle)),
                DataColumn(label: Text('CUSTODY', style: _columnHeaderStyle)),
              ],
              rows: _searchResults.asMap().entries.map<DataRow>((entry) {
                final index = entry.key;
                final profile = entry.value;
                final isSelected = _selectedFirearmId ==
                    (profile['firearm_id']?.toString() ?? '');
                final isLocked = profile['is_locked'] == true;
                final hasHash = profile['registration_hash'] != null &&
                    profile['registration_hash'].toString().isNotEmpty;
                final firearmId = profile['firearm_id']?.toString() ?? '';
                final firearmLabel =
                    '${profile['manufacturer'] ?? ''} ${profile['model'] ?? ''}'
                        .trim();

                return DataRow(
                  selected: isSelected,
                  color: WidgetStateProperty.resolveWith((states) {
                    if (isSelected) {
                      return const Color(0xFF1E88E5).withValues(alpha: 0.08);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return const Color(0xFF2E3546).withValues(alpha: 0.5);
                    }
                    return index.isEven
                        ? const Color(0xFF232838)
                        : const Color(0xFF1E2333);
                  }),
                  onSelectChanged: (_) {
                    if (firearmId.isNotEmpty) {
                      _loadCustodyTimeline(firearmId, firearmLabel);
                    }
                  },
                  cells: [
                    DataCell(Text(
                      firearmLabel.isNotEmpty ? firearmLabel : 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    )),
                    DataCell(Text(
                      profile['serial_number']?.toString() ?? 'N/A',
                      style: const TextStyle(
                        color: Color(0xFF64B5F6),
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    )),
                    DataCell(Text(
                      profile['caliber']?.toString() ?? '\u2014',
                      style: const TextStyle(
                          color: Color(0xFFB0BEC5), fontSize: 13),
                    )),
                    DataCell(_buildCellValue(
                        profile['firing_pin_impression']?.toString())),
                    DataCell(_buildCellValue(
                        profile['rifling_characteristics']?.toString())),
                    DataCell(
                        _buildCellValue(profile['chamber_marks']?.toString())),
                    DataCell(_buildCellValue(_combineBreechFace(
                      profile['ejector_marks']?.toString(),
                      profile['extractor_marks']?.toString(),
                    ))),
                    DataCell(Text(
                      profile['assigned_unit_name']?.toString() ?? '\u2014',
                      style: const TextStyle(
                          color: Color(0xFF90A4AE), fontSize: 13),
                    )),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isLocked && hasHash
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFFA726))
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isLocked && hasHash ? 'Verified' : 'Unverified',
                          style: TextStyle(
                            color: isLocked && hasHash
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFFA726),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      InkWell(
                        onTap: () {
                          if (firearmId.isNotEmpty) {
                            _loadCustodyTimeline(firearmId, firearmLabel);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E88E5)
                                    .withValues(alpha: 0.15)
                                : const Color(0xFF1E88E5)
                                    .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFF1E88E5)
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timeline,
                                size: 15,
                                color: isSelected
                                    ? const Color(0xFF64B5F6)
                                    : const Color(0xFF546E7A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Trace',
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF64B5F6)
                                      : const Color(0xFF78909C),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
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

  Widget _buildCellValue(String? value) {
    if (value == null || value.isEmpty || value == 'null') {
      return const Text(
        '\u2014',
        style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
      );
    }
    final display = value.length > 24 ? '${value.substring(0, 24)}...' : value;
    return Tooltip(
      message: value,
      child: Text(
        display,
        style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
