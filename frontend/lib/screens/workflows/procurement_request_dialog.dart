import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ProcurementRequestDialog extends StatefulWidget {
  final Future<void> Function(List<Map<String, dynamic>> requests,
      String priority, DateTime requiredBy, String justification) onSubmit;

  const ProcurementRequestDialog({super.key, required this.onSubmit});

  @override
  State<ProcurementRequestDialog> createState() =>
      _ProcurementRequestDialogState();
}

class _ProcurementRequestDialogState extends State<ProcurementRequestDialog> {
  final _justificationController = TextEditingController();
  final List<Map<String, dynamic>> _rows = [
    {'type': 'Pistol', 'quantity': 1}
  ];
  final List<TextEditingController> _quantityControllers = [
    TextEditingController(text: '1'),
  ];
  String _urgency = 'routine';
  DateTime _requiredBy = DateTime.now();

  static const _types = [
    'Pistol',
    'Rifle',
    'Shotgun',
    'Submachine Gun',
    'Sniper Rifle',
    'Carbine',
  ];

  int get _total {
    var total = 0;
    for (final controller in _quantityControllers) {
      final quantity = int.tryParse(controller.text.trim()) ?? 0;
      if (quantity > 0) {
        total += quantity;
      }
    }
    return total;
  }

  void _addRow() {
    setState(() {
      _rows.add({'type': 'Rifle', 'quantity': 1});
      _quantityControllers.add(TextEditingController(text: '1'));
    });
  }

  void _removeRow(int index) {
    if (_rows.length > 1) {
      setState(() {
        _rows.removeAt(index);
        _quantityControllers.removeAt(index).dispose();
      });
    }
  }

  int _quantityAt(int index) {
    return int.tryParse(_quantityControllers[index].text.trim()) ?? 0;
  }

  void _setQuantity(int index, int quantity) {
    final safeQuantity = quantity < 1 ? 1 : quantity;
    setState(() {
      _rows[index]['quantity'] = safeQuantity;
      _quantityControllers[index].text = safeQuantity.toString();
      _quantityControllers[index].selection = TextSelection.collapsed(
        offset: _quantityControllers[index].text.length,
      );
    });
  }

  void _submit() async {
    final justification = _justificationController.text.trim();
    if (justification.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please provide operational justification'),
            backgroundColor: Color(0xFFE85C5C)),
      );
      return;
    }

    final validatedRows = <Map<String, dynamic>>[];
    for (var index = 0; index < _rows.length; index++) {
      final quantity = _quantityAt(index);
      if (quantity < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Please enter quantity of at least 1 for each firearm type'),
              backgroundColor: Color(0xFFE85C5C)),
        );
        return;
      }

      _rows[index]['quantity'] = quantity;
      validatedRows.add({
        'type': _rows[index]['type'],
        'quantity': quantity,
      });
    }

    await widget.onSubmit(validatedRows, _urgency, _requiredBy, justification);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _justificationController.dispose();
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF252A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Color(0xFF37404F)),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 24, bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.add_shopping_cart,
                          color: Color(0xFF1E88E5), size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Request Firearms',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Procurement & restock request',
                            style: TextStyle(
                                color: Color(0xFF78909C), fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                      border: Border.all(
                          color:
                              const Color(0xFF1E88E5).withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('New request',
                        style:
                            TextStyle(color: Color(0xFF1E88E5), fontSize: 12)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF37404F)),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('FIREARM TYPES & QUANTITIES',
                        style: TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 8),

                    // Table Header
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text('Type',
                                  style: TextStyle(
                                      color: Color(0xFF78909C), fontSize: 13))),
                          SizedBox(
                              width: 130,
                              child: Text('Quantity',
                                  style: TextStyle(
                                      color: Color(0xFF78909C), fontSize: 13))),
                          SizedBox(width: 34),
                        ],
                      ),
                    ),

                    // Rows
                    ..._rows.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Map<String, dynamic> row = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2E),
                          border: Border.all(color: const Color(0xFF37404F)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            // Dropdown
                            Expanded(
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252A3A),
                                  border: Border.all(
                                      color: const Color(0xFF37404F)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: row['type'],
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF252A3A),
                                    icon: const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(Icons.arrow_drop_down,
                                          color: Color(0xFF78909C), size: 20),
                                    ),
                                    padding: const EdgeInsets.only(left: 12),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                    items: _types
                                        .map((t) => DropdownMenuItem(
                                            value: t, child: Text(t)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => row['type'] = v!),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Quantity
                            Container(
                              width: 130,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF252A3A),
                                border:
                                    Border.all(color: const Color(0xFF37404F)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    key: ValueKey(
                                        'procurement-quantity-decrement-$idx'),
                                    onTap: () =>
                                        _setQuantity(idx, _quantityAt(idx) - 1),
                                    child: const SizedBox(
                                        width: 36,
                                        height: 40,
                                        child: Center(
                                            child: Text('−',
                                                style: TextStyle(
                                                    color: Color(0xFF1E88E5),
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.w500)))),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      key: ValueKey(
                                          'procurement-quantity-input-$idx'),
                                      controller: _quantityControllers[idx],
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          row['quantity'] =
                                              int.tryParse(value.trim()) ?? 0;
                                        });
                                      },
                                    ),
                                  ),
                                  InkWell(
                                    key: ValueKey(
                                        'procurement-quantity-increment-$idx'),
                                    onTap: () =>
                                        _setQuantity(idx, _quantityAt(idx) + 1),
                                    child: const SizedBox(
                                        width: 36,
                                        height: 40,
                                        child: Center(
                                            child: Text('+',
                                                style: TextStyle(
                                                    color: Color(0xFF1E88E5),
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.w500)))),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Remove button
                            SizedBox(
                              width: 34,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                color: const Color(0xFFE85C5C),
                                hoverColor: const Color(0xFFE85C5C)
                                    .withValues(alpha: 0.1),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                onPressed: _rows.length > 1
                                    ? () => _removeRow(idx)
                                    : null,
                              ),
                            )
                          ],
                        ),
                      );
                    }),

                    // Add Row Button
                    InkWell(
                      onTap: _addRow,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF37404F),
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Color(0xFF1E88E5), size: 16),
                            SizedBox(width: 8),
                            Text('Add firearm type',
                                style: TextStyle(
                                    color: Color(0xFF1E88E5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFF37404F)),
                    const SizedBox(height: 24),

                    // Urgency
                    const Text('URGENCY LEVEL',
                        style: TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildUrgencyBtn(
                            'routine',
                            'Routine',
                            Icons.check_circle_outline,
                            const Color(0xFF0B1F17),
                            const Color(0xFF1A4030),
                            const Color(0xFF4ADE80)),
                        const SizedBox(width: 6),
                        _buildUrgencyBtn(
                            'urgent',
                            'Urgent',
                            Icons.warning_amber_rounded,
                            const Color(0xFF1F1A08),
                            const Color(0xFF3D3010),
                            const Color(0xFFFBBF24)),
                        const SizedBox(width: 6),
                        _buildUrgencyBtn(
                            'critical',
                            'Critical',
                            Icons.local_fire_department_outlined,
                            const Color(0xFF1F0B0B),
                            const Color(0xFF3D1515),
                            const Color(0xFFF87171)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Grid
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('REQUIRED BY',
                                  style: TextStyle(
                                      color: Color(0xFFB0BEC5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _requiredBy,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setState(() => _requiredBy = date);
                                  }
                                },
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF252A3A),
                                    border: Border.all(
                                        color: const Color(0xFF37404F)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                      DateFormat('yyyy-MM-dd')
                                          .format(_requiredBy),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('REFERENCE NO.',
                                  style: TextStyle(
                                      color: Color(0xFFB0BEC5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8)),
                              const SizedBox(height: 8),
                              Container(
                                height: 40,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1F2E),
                                  border: Border.all(
                                      color: const Color(0xFF37404F)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.centerLeft,
                                child: const Text('Auto-generated',
                                    style: TextStyle(
                                        color: Color(0xFF78909C),
                                        fontSize: 14)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Justification
                    const Text('OPERATIONAL JUSTIFICATION',
                        style: TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF252A3A),
                        border: Border.all(color: const Color(0xFF37404F)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextField(
                        key: const Key('procurement-justification-input'),
                        controller: _justificationController,
                        maxLines: 4,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText:
                              'Describe the operational need, mission context, or replacement reason...',
                          hintStyle:
                              TextStyle(color: Color(0xFF78909C), fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Summary
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F2E),
                        border: Border.all(color: const Color(0xFF37404F)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  color: Color(0xFFB0BEC5), size: 18),
                              SizedBox(width: 8),
                              Text('Total firearms requested',
                                  style: TextStyle(
                                      color: Color(0xFFB0BEC5), fontSize: 14)),
                            ],
                          ),
                          Text('$_total',
                              key: const Key('procurement-total-quantity'),
                              style: const TextStyle(
                                  color: Color(0xFF1E88E5),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFF37404F)),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1F2E),
                borderRadius: BorderRadius.zero,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const info = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security, color: Color(0xFF78909C), size: 14),
                      SizedBox(width: 6),
                      Text('Requires commander approval',
                          style: TextStyle(
                              color: Color(0xFF78909C), fontSize: 12)),
                    ],
                  );
                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF78909C),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        key: const Key('procurement-submit-button'),
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Submit request',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        info,
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerRight, child: actions),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [info, actions],
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyBtn(String val, String label, IconData icon, Color bg,
      Color border, Color fg) {
    bool isSel = _urgency == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _urgency = val),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSel ? bg : const Color(0xFF1A1F2E),
            border: Border.all(color: isSel ? border : const Color(0xFF37404F)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSel ? fg : const Color(0xFF78909C), size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      style: TextStyle(
                          color: isSel ? fg : const Color(0xFF78909C),
                          fontSize: 13,
                          fontWeight:
                              isSel ? FontWeight.w600 : FontWeight.normal)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
