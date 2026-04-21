import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpandableReportCard extends StatefulWidget {
  final String reportId;
  final String status;
  final String primaryCodeLabel;
  final String primaryCodeValue;
  final DateTime dateReported;
  final String? location;
  final String? reportingUnit;
  final String circumstancesLabel;
  final String circumstances;
  final Color severityColor;
  final Widget detailsWidget;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onStatusChanged;

  const ExpandableReportCard({
    super.key,
    required this.reportId,
    required this.status,
    required this.primaryCodeLabel,
    required this.primaryCodeValue,
    required this.dateReported,
    this.location,
    this.reportingUnit,
    required this.circumstancesLabel,
    required this.circumstances,
    required this.severityColor,
    required this.detailsWidget,
    this.onDelete,
    this.onStatusChanged,
  });

  @override
  State<ExpandableReportCard> createState() => _ExpandableReportCardState();
}

class _ExpandableReportCardState extends State<ExpandableReportCard> {
  bool _isExpanded = false;
  bool _isHovered = false;
  late String _currentStatus;
  // Single source of truth for programmatic expand/collapse.
  // Drives both the ExpansionTile and the "View Details" button.
  final ExpansibleController _expansionController = ExpansibleController();

  // Colors based on requested theme
  static const Color _cardBgColor = Color(0xFF212D42);
  static const Color _primaryText = Color(0xFFE8EDF5);
  static const Color _secondaryText = Color(0xFF8B97AA);
  static const Color _mutedText = Color(0xFF5A6478);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentBlueDim = Color(0x263B82F6); // 15% opacity
  static const Color _borderDefault = Color(0x12FFFFFF); // 7% opacity
  static const Color _borderHover = Color(0x1EFFFFFF); // 12% opacity
  static const Color _dangerRed = Color(0xFFEF4444);
  static const Color _approvedGreen = Color(0xFF22C55E);
  static const Color _amberWarn = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status.toLowerCase();
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ExpandableReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      setState(() {
        _currentStatus = widget.status.toLowerCase();
      });
    }
  }

  void _cycleStatus() {
    if (widget.onStatusChanged == null) return;
    String nextStatus;
    if (_currentStatus == 'pending') {
      nextStatus = 'approved';
    } else if (_currentStatus == 'approved') {
      nextStatus = 'rejected';
    } else {
      nextStatus = 'pending';
    }

    setState(() {
      _currentStatus = nextStatus;
    });
    widget.onStatusChanged!(nextStatus);
  }

  void _confirmDelete() {
    if (widget.onDelete == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2233),
        title: const Text('Confirm Deletion',
            style: TextStyle(color: _primaryText)),
        content: Text(
            'Are you sure you want to delete report ${widget.reportId}?',
            style: const TextStyle(color: _secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: _secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _dangerRed),
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete!();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case 'approved':
        return _approvedGreen;
      case 'rejected':
        return _dangerRed;
      default:
        return _amberWarn;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 16),
        transform: Matrix4.translationValues(0, _isHovered ? -1.0 : 0.0, 0),
        decoration: BoxDecoration(
          color: _cardBgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered ? _borderHover : _borderDefault,
            width: 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(color: widget.severityColor, width: 4)),
            ),
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                controller: _expansionController,
                onExpansionChanged: (expanded) {
                  setState(() => _isExpanded = expanded);
                },
                tilePadding: const EdgeInsets.all(16),
                title: _buildPreview(),
                trailing:
                    const SizedBox.shrink(), // Custom trailing placed in header
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _borderDefault)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: widget.detailsWidget,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.severityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.reportId,
                  style: const TextStyle(
                    fontFamily: 'DM Mono',
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: _cycleStatus,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor().withValues(alpha: 0.5),
                      ),
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        color: _getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      child: Text(_currentStatus.toUpperCase()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: _mutedText,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.primaryCodeLabel.toUpperCase(),
                      style: const TextStyle(
                          color: _mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(widget.primaryCodeValue,
                      style: const TextStyle(
                          fontFamily: 'DM Mono',
                          color: _accentBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  if (widget.location != null) ...[
                    const SizedBox(height: 12),
                    const Text('LOCATION',
                        style: TextStyle(
                            color: _mutedText,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.location!,
                        style:
                            const TextStyle(color: _primaryText, fontSize: 14)),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DATE REPORTED',
                      style: TextStyle(
                          color: _mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(DateFormat('MMM dd, yyyy').format(widget.dateReported),
                      style:
                          const TextStyle(color: _primaryText, fontSize: 14)),
                  if (widget.reportingUnit != null) ...[
                    const SizedBox(height: 12),
                    const Text('REPORTING UNIT',
                        style: TextStyle(
                            color: _mutedText,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.reportingUnit!,
                        style:
                            const TextStyle(color: _primaryText, fontSize: 14)),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(widget.circumstancesLabel.toUpperCase(),
            style: const TextStyle(
                color: _mutedText, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          widget.circumstances,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _secondaryText, fontSize: 14),
        ),
        const SizedBox(height: 16),
        const Divider(color: _borderDefault, height: 1),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.onDelete != null)
              TextButton(
                onPressed: _confirmDelete,
                style: TextButton.styleFrom(foregroundColor: _dangerRed),
                child: const Text('Delete'),
              ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (_isExpanded) {
                  _expansionController.collapse();
                } else {
                  _expansionController.expand();
                }
                // _isExpanded is updated by onExpansionChanged callback above
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlueDim,
                foregroundColor: _accentBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                side: const BorderSide(color: _accentBlue, width: 1),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  _isExpanded ? 'Hide Details' : 'View Details',
                  key: ValueKey(_isExpanded),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
