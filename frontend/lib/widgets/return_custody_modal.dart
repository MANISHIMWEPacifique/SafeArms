// Return Custody Modal - Station Commander Level
// Modal for returning firearm from custody
// SafeArms Frontend

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/custody_provider.dart';

class ReturnCustodyModal extends StatefulWidget {
  final Map<String, dynamic> custodyRecord;
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const ReturnCustodyModal({
    Key? key,
    required this.custodyRecord,
    required this.onClose,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<ReturnCustodyModal> createState() => _ReturnCustodyModalState();
}

class _ReturnCustodyModalState extends State<ReturnCustodyModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  String _returnCondition = 'good';
  DateTime _returnDate = DateTime.now();
  bool _isSubmitting = false;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final custodyProvider = context.read<CustodyProvider>();
    final success = await custodyProvider.returnFirearm(
      custodyId: widget.custodyRecord['custody_id'].toString(),
      returnCondition: _returnCondition,
      returnDate: _returnDate,
      returnNotes: _notesController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (success) {
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firearm returned successfully'),
          backgroundColor: Color(0xFF3CCB7F),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(custodyProvider.errorMessage ?? 'Failed to return firearm'),
          backgroundColor: const Color(0xFFE85C5C),
        ),
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1F2E).withOpacity(0.95),
      child: Center(
        child: Container(
          width: 550,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCustodyInfo(),
                        const SizedBox(height: 24),
                        _buildConditionSelection(),
                        const SizedBox(height: 24),
                        _buildReturnDate(),
                        const SizedBox(height: 24),
                        _buildNotes(),
                      ],
                    ),
                  ),
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF42A5F5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_return,
              color: Color(0xFF42A5F5),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Return Firearm',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Serial: ${widget.custodyRecord['firearm_serial'] ?? 'N/A'}',
                  style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 14,
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
    );
  }

  Widget _buildCustodyInfo() {
    final custody = widget.custodyRecord;
    final assignedDate = DateTime.tryParse(custody['assigned_date'] ?? '');
    final duration = assignedDate != null
        ? DateTime.now().difference(assignedDate)
        : Duration.zero;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.gavel,
            label: 'Firearm',
            value: '${custody['manufacturer'] ?? ''} ${custody['model'] ?? ''}'
                .trim(),
          ),
          const Divider(color: Color(0xFF37404F), height: 24),
          _buildInfoRow(
            icon: Icons.person,
            label: 'Officer',
            value: custody['officer_name'] ?? 'Unknown',
          ),
          const Divider(color: Color(0xFF37404F), height: 24),
          _buildInfoRow(
            icon: Icons.category,
            label: 'Custody Type',
            value: _formatCustodyType(custody['custody_type'] ?? 'permanent'),
          ),
          const Divider(color: Color(0xFF37404F), height: 24),
          _buildInfoRow(
            icon: Icons.access_time,
            label: 'Duration',
            value: _formatDuration(duration),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF78909C), size: 18),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildConditionSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Return Condition',
              style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Text('*', style: TextStyle(color: Color(0xFFE85C5C))),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildConditionChip(
              'good',
              'Good',
              Icons.check_circle,
              const Color(0xFF3CCB7F),
            ),
            _buildConditionChip(
              'minor_issues',
              'Minor Issues',
              Icons.warning_amber,
              const Color(0xFFFFC857),
            ),
            _buildConditionChip(
              'needs_maintenance',
              'Needs Maintenance',
              Icons.build,
              const Color(0xFFFF9800),
            ),
            _buildConditionChip(
              'damaged',
              'Damaged',
              Icons.error,
              const Color(0xFFE85C5C),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionChip(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _returnCondition == value;
    return InkWell(
      onTap: () => setState(() => _returnCondition = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF2A3040),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF37404F),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : const Color(0xFF78909C),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFFB0BEC5),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Return Date',
          style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _returnDate,
              firstDate: DateTime.now().subtract(const Duration(days: 7)),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _returnDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              border: Border.all(color: const Color(0xFF37404F)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF78909C),
                  size: 16,
                ),
                const SizedBox(width: 12),
                Text(
                  '${_returnDate.day}/${_returnDate.month}/${_returnDate.year}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Return Notes',
          style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Any notes about the return...',
            hintStyle: const TextStyle(color: Color(0xFF78909C)),
            filled: true,
            fillColor: const Color(0xFF2A3040),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: widget.onClose,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB0BEC5),
              side: const BorderSide(color: Color(0xFF37404F)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitForm,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.assignment_turned_in, size: 18),
            label: const Text(
              'Confirm Return',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCustodyType(String type) {
    switch (type) {
      case 'permanent':
        return 'Permanent';
      case 'temporary':
        return 'Temporary';
      case 'personal_long_term':
        return 'Personal Long-term';
      default:
        return type;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} days';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours';
    } else {
      return '${duration.inMinutes} minutes';
    }
  }
}
