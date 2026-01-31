// Enhanced Firearm Detail Modal with Forensic Traceability
// SafeArms Frontend
//
// IMPORTANT: This modal presents FACTUAL data only.
// No judgmental indicators (red/green verdicts) are used.
// Anomalies are labeled "Requires Review" NOT "Suspicious"

import 'package:flutter/material.dart';
import '../models/firearm_model.dart';
import '../services/forensic_traceability_service.dart';
import 'custody_timeline_widget.dart';
import 'ballistic_profile_view_widget.dart';
import 'ballistic_access_history_widget.dart';
import 'anomaly_review_indicator_widget.dart';

class ForensicFirearmDetailModal extends StatefulWidget {
  final FirearmModel firearm;
  final VoidCallback onClose;
  final VoidCallback? onEdit;

  const ForensicFirearmDetailModal({
    Key? key,
    required this.firearm,
    required this.onClose,
    this.onEdit,
  }) : super(key: key);

  @override
  State<ForensicFirearmDetailModal> createState() =>
      _ForensicFirearmDetailModalState();
}

class _ForensicFirearmDetailModalState extends State<ForensicFirearmDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ForensicTraceabilityService _traceabilityService =
      ForensicTraceabilityService();

  // Data states
  bool _isLoadingTimeline = true;
  bool _isLoadingBallistic = true;
  bool _isLoadingAccessHistory = true;
  bool _isLoadingAnomalies = true;

  List<Map<String, dynamic>> _custodyTimeline = [];
  Map<String, dynamic>? _custodySummary;
  Map<String, dynamic>? _ballisticProfile;
  List<Map<String, dynamic>> _accessHistory = [];
  List<Map<String, dynamic>> _anomalies = [];

  String? _timelineError;
  String? _ballisticError;
  String? _accessHistoryError;
  String? _anomaliesError;

  bool _ballisticAccessDenied = false;
  bool _accessHistoryDenied = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadForensicData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadForensicData() async {
    _loadCustodyTimeline();
    _loadBallisticProfile();
    _loadAccessHistory();
    _loadAnomalies();
  }

  Future<void> _loadCustodyTimeline() async {
    try {
      setState(() {
        _isLoadingTimeline = true;
        _timelineError = null;
      });

      final response = await _traceabilityService.getCustodyTimeline(
        widget.firearm.firearmId,
      );

      setState(() {
        // Extract timeline list and summary from API response
        final timelineData = response['timeline'];
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

  Future<void> _loadBallisticProfile() async {
    try {
      setState(() {
        _isLoadingBallistic = true;
        _ballisticError = null;
        _ballisticAccessDenied = false;
      });

      final profile = await _traceabilityService.getBallisticProfile(
        widget.firearm.firearmId,
      );

      setState(() {
        _ballisticProfile = profile;
        _isLoadingBallistic = false;
      });
    } catch (e) {
      if (e.toString().contains('403') || e.toString().contains('forbidden')) {
        setState(() {
          _ballisticAccessDenied = true;
          _isLoadingBallistic = false;
        });
      } else {
        setState(() {
          _ballisticError = 'Unable to load ballistic profile';
          _isLoadingBallistic = false;
        });
      }
    }
  }

  Future<void> _loadAccessHistory() async {
    try {
      setState(() {
        _isLoadingAccessHistory = true;
        _accessHistoryError = null;
        _accessHistoryDenied = false;
      });

      final history = await _traceabilityService.getBallisticAccessHistory(
        widget.firearm.firearmId,
      );

      setState(() {
        _accessHistory = history;
        _isLoadingAccessHistory = false;
      });
    } catch (e) {
      if (e.toString().contains('403') || e.toString().contains('forbidden')) {
        setState(() {
          _accessHistoryDenied = true;
          _isLoadingAccessHistory = false;
        });
      } else {
        setState(() {
          _accessHistoryError = 'Unable to load access history';
          _isLoadingAccessHistory = false;
        });
      }
    }
  }

  Future<void> _loadAnomalies() async {
    try {
      setState(() {
        _isLoadingAnomalies = true;
        _anomaliesError = null;
      });

      final anomalies = await _traceabilityService.getFirearmAnomalies(
        widget.firearm.firearmId,
      );

      setState(() {
        _anomalies = anomalies;
        _isLoadingAnomalies = false;
      });
    } catch (e) {
      setState(() {
        _anomaliesError = 'Unable to load review items';
        _isLoadingAnomalies = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1F2E).withOpacity(0.95),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(color: Colors.transparent),
            ),
          ),
          Container(
            width: 600, // Slightly wider to accommodate forensic data
            decoration: const BoxDecoration(
              color: Color(0xFF252A3A),
              boxShadow: [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 20,
                  offset: Offset(-4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildCustodyTimelineTab(),
                      _buildBallisticTab(),
                      _buildReviewTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Firearm Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Anomaly review indicator in header
                        if (!_isLoadingAnomalies && _anomalies.isNotEmpty)
                          AnomalyReviewIndicatorWidget(
                            anomalies: _anomalies,
                            isCompact: true,
                            onViewDetails: () {
                              _tabController.animateTo(3); // Go to Review tab
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.firearm.serialNumber,
                      style: const TextStyle(
                        color: Color(0xFF78909C),
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF78909C)),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF42A5F5),
        unselectedLabelColor: const Color(0xFF78909C),
        indicatorColor: const Color(0xFF42A5F5),
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: [
          const Tab(text: 'Overview'),
          const Tab(text: 'Custody Timeline'),
          const Tab(text: 'Ballistic Profile'),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Review'),
                if (!_isLoadingAnomalies && _anomalies.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_anomalies.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileSection(),
          const SizedBox(height: 24),
          _buildSpecificationsSection(),
          const SizedBox(height: 24),
          _buildAcquisitionSection(),
          const SizedBox(height: 24),
          _buildStatusSection(),
          const SizedBox(height: 24),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildCustodyTimelineTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: CustodyTimelineWidget(
        timeline: _custodyTimeline,
        summary: _custodySummary,
        isLoading: _isLoadingTimeline,
        errorMessage: _timelineError,
      ),
    );
  }

  Widget _buildBallisticTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BallisticProfileViewWidget(
            profile: _ballisticProfile,
            isLoading: _isLoadingBallistic,
            errorMessage: _ballisticError,
            accessDenied: _ballisticAccessDenied,
            onViewAccessHistory: () {
              // Show access history section
              _showAccessHistoryDialog();
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Access History',
            style: TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          BallisticAccessHistoryWidget(
            accessHistory: _accessHistory,
            isLoading: _isLoadingAccessHistory,
            errorMessage: _accessHistoryError,
            accessDenied: _accessHistoryDenied,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              border: Border.all(color: const Color(0xFF37404F)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF78909C),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Events listed here require human review. They indicate patterns that warrant attention, not wrongdoing.',
                    style: const TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoadingAnomalies)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
              ),
            )
          else if (_anomaliesError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _anomaliesError!,
                  style: const TextStyle(color: Color(0xFF78909C)),
                ),
              ),
            )
          else if (_anomalies.isEmpty)
            _buildNoReviewItemsState()
          else
            AnomalyReviewIndicatorWidget(
              anomalies: _anomalies,
              isCompact: false,
            ),
        ],
      ),
    );
  }

  Widget _buildNoReviewItemsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: const [
          Icon(Icons.check_circle_outline, color: Color(0xFF78909C), size: 48),
          SizedBox(height: 16),
          Text(
            'No Pending Reviews',
            style: TextStyle(
              color: Color(0xFF78909C),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'There are no events requiring review for this firearm',
            style: TextStyle(color: Color(0xFF546E7A), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAccessHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF252A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Ballistic Profile Access History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF78909C)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF37404F), height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: BallisticAccessHistoryWidget(
                    accessHistory: _accessHistory,
                    isLoading: _isLoadingAccessHistory,
                    errorMessage: _accessHistoryError,
                    accessDenied: _accessHistoryDenied,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reused from original modal - Profile Section
  Widget _buildProfileSection() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: Color(0xFF2A3040),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getFirearmIcon(widget.firearm.firearmType),
            color: const Color(0xFF42A5F5),
            size: 50,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${widget.firearm.manufacturer} ${widget.firearm.model}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatusBadge(widget.firearm.currentStatus),
            const SizedBox(width: 8),
            _buildRegistrationLevelBadge(widget.firearm.registrationLevel),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecificationsSection() {
    return _buildInfoSection('Specifications', [
      _buildInfoRow('Type', _formatFirearmType(widget.firearm.firearmType)),
      _buildInfoRow('Caliber', widget.firearm.caliber ?? 'N/A'),
      _buildInfoRow('Manufacture Year',
          widget.firearm.manufactureYear?.toString() ?? 'N/A'),
      _buildInfoRow('Manufacturer', widget.firearm.manufacturer),
      _buildInfoRow('Model', widget.firearm.model),
    ]);
  }

  Widget _buildAcquisitionSection() {
    return _buildInfoSection('Acquisition Details', [
      _buildInfoRow(
          'Acquisition Date', _formatDate(widget.firearm.acquisitionDate)),
      _buildInfoRow('Source', widget.firearm.acquisitionSource ?? 'N/A'),
      _buildInfoRow('Registered By', widget.firearm.registeredBy),
    ]);
  }

  Widget _buildStatusSection() {
    return _buildInfoSection('Current Status', [
      _buildInfoRow('Status', widget.firearm.currentStatus.toUpperCase()),
      _buildInfoRow('Assigned Unit', widget.firearm.unitDisplayName),
      _buildInfoRow(
          'Registration Level', widget.firearm.registrationLevel.toUpperCase()),
      _buildInfoRow('Active', widget.firearm.isActive ? 'Yes' : 'No'),
    ]);
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.onEdit != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Firearm Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _tabController.animateTo(1); // Go to Custody Timeline
            },
            icon: const Icon(Icons.timeline, size: 18),
            label: const Text('View Full Custody Timeline'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF42A5F5),
              side: const BorderSide(color: Color(0xFF42A5F5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _tabController.animateTo(2); // Go to Ballistic Profile
            },
            icon: const Icon(Icons.fingerprint, size: 18),
            label: const Text('View Ballistic Profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF78909C),
              side: const BorderSide(color: Color(0xFF37404F)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            border: Border.all(color: const Color(0xFF37404F)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Color(0xFF37404F), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    String displayText;

    switch (status) {
      case 'available':
        backgroundColor =
            const Color(0xFF78909C); // Neutral gray instead of green
        displayText = 'AVAILABLE';
        break;
      case 'in_custody':
        backgroundColor = const Color(0xFF42A5F5);
        displayText = 'IN CUSTODY';
        break;
      case 'maintenance':
        backgroundColor = const Color(0xFF78909C);
        displayText = 'MAINTENANCE';
        break;
      case 'lost':
      case 'stolen':
        backgroundColor = const Color(0xFF78909C); // Neutral instead of red
        displayText = status.toUpperCase();
        break;
      default:
        backgroundColor = const Color(0xFF78909C);
        displayText = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRegistrationLevelBadge(String level) {
    final isHQ = level == 'hq';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF42A5F5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHQ ? Icons.domain : Icons.business,
            size: 14,
            color: const Color(0xFF42A5F5),
          ),
          const SizedBox(width: 4),
          Text(
            isHQ ? 'HQ REGISTERED' : 'UNIT REGISTERED',
            style: const TextStyle(
              color: Color(0xFF42A5F5),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFirearmIcon(String type) {
    switch (type) {
      case 'pistol':
        return Icons.sports_martial_arts;
      case 'rifle':
        return Icons.yard;
      case 'shotgun':
        return Icons.wifi_protected_setup;
      default:
        return Icons.hardware;
    }
  }

  String _formatFirearmType(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
