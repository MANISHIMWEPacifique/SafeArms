// Units Management Screen
// Manage police units and stations
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/unit_provider.dart';

class UnitsManagementScreen extends StatefulWidget {
  const UnitsManagementScreen({Key? key}) : super(key: key);

  @override
  State<UnitsManagementScreen> createState() => _UnitsManagementScreenState();
}

class _UnitsManagementScreenState extends State<UnitsManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UnitProvider>().loadUnits();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Units Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage police units and stations across the country',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddUnitDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Unit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Filters Row
          Row(
            children: [
              // Search
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search units...',
                    hintStyle: const TextStyle(color: Color(0xFF78909C)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF78909C),
                    ),
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
                      borderSide: const BorderSide(color: Color(0xFF1E88E5)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Type Filter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3040),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF37404F)),
                  ),
                  child: DropdownButton<String>(
                    value: _typeFilter,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A3040),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Types')),
                      DropdownMenuItem(
                        value: 'station',
                        child: Text('Police Station'),
                      ),
                      DropdownMenuItem(
                        value: 'headquarters',
                        child: Text('Headquarters'),
                      ),
                      DropdownMenuItem(
                        value: 'training_school',
                        child: Text('Training School'),
                      ),
                      DropdownMenuItem(
                        value: 'special_unit',
                        child: Text('Special Unit'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _typeFilter = value ?? 'all';
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Units List
          Consumer<UnitProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
                );
              }

              if (provider.error != null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFE85C5C),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        provider.error!,
                        style: const TextStyle(color: Color(0xFFE85C5C)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => provider.loadUnits(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final units = _filterUnits(provider.units);

              if (units.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3040),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF37404F)),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business,
                          size: 64,
                          color: Color(0xFF78909C),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No units found',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add a new unit to get started',
                          style: TextStyle(color: Color(0xFF78909C)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3040),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF37404F)),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF37404F)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 3,
                            child: Text(
                              'Unit Name',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Type',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Location',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 1,
                            child: Text(
                              'Firearms',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 1,
                            child: Text(
                              'Officers',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 1,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 80),
                        ],
                      ),
                    ),

                    // Table Body
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: units.length,
                      separatorBuilder: (_, __) => const Divider(
                        color: Color(0xFF37404F),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final unit = units[index];
                        return _buildUnitRow(unit);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<dynamic> _filterUnits(List<dynamic> units) {
    return units.where((unit) {
      // Search filter
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        final name = (unit['unit_name'] ?? '').toString().toLowerCase();
        final location = (unit['location'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !location.contains(query)) {
          return false;
        }
      }

      // Type filter
      if (_typeFilter != 'all') {
        if (unit['unit_type'] != _typeFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildUnitRow(dynamic unit) {
    // Get stats from unit data (or default to 0)
    final firearmCount = unit['firearm_count'] ?? unit['firearms_count'] ?? 0;
    final officerCount = unit['officer_count'] ?? unit['officers_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getUnitIcon(unit['unit_type']),
                    color: const Color(0xFF1E88E5),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit['unit_name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (unit['commander_name'] != null)
                        Text(
                          'Cmd: ${unit['commander_name']}',
                          style: const TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getTypeColor(unit['unit_type']).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatUnitType(unit['unit_type']),
                style: TextStyle(
                  color: _getTypeColor(unit['unit_type']),
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '${unit['district'] ?? ''}, ${unit['province'] ?? ''}',
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Firearms count with icon
          Expanded(
            flex: 1,
            child: Row(
              children: [
                const Icon(Icons.gavel, color: Color(0xFF42A5F5), size: 16),
                const SizedBox(width: 6),
                Text(
                  '$firearmCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Officers count with icon
          Expanded(
            flex: 1,
            child: Row(
              children: [
                const Icon(Icons.badge, color: Color(0xFF3CCB7F), size: 16),
                const SizedBox(width: 6),
                Text(
                  '$officerCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: unit['is_active'] == true
                    ? const Color(0xFF3CCB7F).withValues(alpha: 0.2)
                    : const Color(0xFFE85C5C).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unit['is_active'] == true ? 'Active' : 'Inactive',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: unit['is_active'] == true
                      ? const Color(0xFF3CCB7F)
                      : const Color(0xFFE85C5C),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit,
                      color: Color(0xFF78909C), size: 18),
                  onPressed: () => _showEditUnitDialog(unit),
                  tooltip: 'Edit',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  icon: const Icon(Icons.visibility,
                      color: Color(0xFF78909C), size: 18),
                  onPressed: () => _showUnitDetails(unit),
                  tooltip: 'View Details',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  icon: const Icon(Icons.assessment,
                      color: Color(0xFF1E88E5), size: 18),
                  onPressed: () => _showUnitStats(unit),
                  tooltip: 'View Stats',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getUnitIcon(String? type) {
    switch (type) {
      case 'headquarters':
        return Icons.account_balance;
      case 'training_school':
        return Icons.school;
      case 'special_unit':
        return Icons.security;
      default:
        return Icons.local_police;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'headquarters':
        return const Color(0xFF1E88E5);
      case 'training_school':
        return const Color(0xFFFFC857);
      case 'special_unit':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF3CCB7F);
    }
  }

  String _formatUnitType(String? type) {
    switch (type) {
      case 'headquarters':
        return 'Headquarters';
      case 'training_school':
        return 'Training School';
      case 'special_unit':
        return 'Special Unit';
      case 'station':
        return 'Police Station';
      default:
        return type ?? 'Unknown';
    }
  }

  void _showAddUnitDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final provinceController = TextEditingController();
    final districtController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String selectedType = 'station';
    bool isActive = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A3040),
          title: const Row(
            children: [
              Icon(Icons.add_business, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('Add New Unit', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(
                      nameController, 'Unit Name', Icons.business),
                  const SizedBox(height: 16),
                  _buildDialogDropdown(
                    value: selectedType,
                    label: 'Unit Type',
                    items: const [
                      DropdownMenuItem(
                          value: 'station', child: Text('Police Station')),
                      DropdownMenuItem(
                          value: 'headquarters', child: Text('Headquarters')),
                      DropdownMenuItem(
                          value: 'training_school',
                          child: Text('Training School')),
                      DropdownMenuItem(
                          value: 'special_unit', child: Text('Special Unit')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedType = value!),
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                      locationController, 'Location', Icons.location_on),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _buildDialogTextField(
                              provinceController, 'Province', Icons.map)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildDialogTextField(
                              districtController, 'District', Icons.place)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                      phoneController, 'Contact Phone', Icons.phone),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                      emailController, 'Contact Email', Icons.email),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Status:',
                          style: TextStyle(color: Color(0xFF78909C))),
                      const SizedBox(width: 12),
                      Switch(
                        value: isActive,
                        onChanged: (value) =>
                            setDialogState(() => isActive = value),
                        activeColor: const Color(0xFF3CCB7F),
                      ),
                      Text(isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                              color: isActive
                                  ? const Color(0xFF3CCB7F)
                                  : const Color(0xFF78909C))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF78909C))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('Unit name is required'),
                        backgroundColor: Color(0xFFE85C5C)),
                  );
                  return;
                }
                final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                final unitProvider = context.read<UnitProvider>();
                Navigator.pop(dialogContext);
                final success = await unitProvider.createUnit({
                  'unit_name': nameController.text,
                  'unit_type': selectedType,
                  'location': locationController.text,
                  'province': provinceController.text,
                  'district': districtController.text,
                  'contact_phone': phoneController.text,
                  'contact_email': emailController.text,
                  'is_active': isActive,
                });
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Unit created successfully'
                        : 'Failed to create unit'),
                    backgroundColor: success
                        ? const Color(0xFF3CCB7F)
                        : const Color(0xFFE85C5C),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5)),
              child: const Text('Create Unit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUnitDialog(dynamic unit) {
    final nameController = TextEditingController(text: unit['unit_name'] ?? '');
    final locationController =
        TextEditingController(text: unit['location'] ?? '');
    final provinceController =
        TextEditingController(text: unit['province'] ?? '');
    final districtController =
        TextEditingController(text: unit['district'] ?? '');
    final phoneController =
        TextEditingController(text: unit['contact_phone'] ?? '');
    final emailController =
        TextEditingController(text: unit['contact_email'] ?? '');
    String selectedType = unit['unit_type'] ?? 'station';
    bool isActive = unit['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A3040),
          title: Row(
            children: [
              const Icon(Icons.edit, color: Color(0xFF1E88E5)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Edit ${unit['unit_name']}',
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(
                      nameController, 'Unit Name', Icons.business),
                  const SizedBox(height: 16),
                  _buildDialogDropdown(
                    value: selectedType,
                    label: 'Unit Type',
                    items: const [
                      DropdownMenuItem(
                          value: 'station', child: Text('Police Station')),
                      DropdownMenuItem(
                          value: 'headquarters', child: Text('Headquarters')),
                      DropdownMenuItem(
                          value: 'training_school',
                          child: Text('Training School')),
                      DropdownMenuItem(
                          value: 'special_unit', child: Text('Special Unit')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedType = value!),
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                      locationController, 'Location', Icons.location_on),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _buildDialogTextField(
                              provinceController, 'Province', Icons.map)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildDialogTextField(
                              districtController, 'District', Icons.place)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                      phoneController, 'Contact Phone', Icons.phone),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                      emailController, 'Contact Email', Icons.email),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Status:',
                          style: TextStyle(color: Color(0xFF78909C))),
                      const SizedBox(width: 12),
                      Switch(
                        value: isActive,
                        onChanged: (value) =>
                            setDialogState(() => isActive = value),
                        activeColor: const Color(0xFF3CCB7F),
                      ),
                      Text(isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                              color: isActive
                                  ? const Color(0xFF3CCB7F)
                                  : const Color(0xFF78909C))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF78909C))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('Unit name is required'),
                        backgroundColor: Color(0xFFE85C5C)),
                  );
                  return;
                }
                final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                final unitProvider = context.read<UnitProvider>();
                Navigator.pop(dialogContext);
                final success = await unitProvider.updateUnit(
                  unit['unit_id'].toString(),
                  {
                    'unit_name': nameController.text,
                    'unit_type': selectedType,
                    'location': locationController.text,
                    'province': provinceController.text,
                    'district': districtController.text,
                    'contact_phone': phoneController.text,
                    'contact_email': emailController.text,
                    'is_active': isActive,
                  },
                );
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Unit updated successfully'
                        : 'Failed to update unit'),
                    backgroundColor: success
                        ? const Color(0xFF3CCB7F)
                        : const Color(0xFFE85C5C),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5)),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF78909C)),
        prefixIcon: Icon(icon, color: const Color(0xFF78909C)),
        filled: true,
        fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E88E5))),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required String value,
    required String label,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF2A3040),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF78909C)),
        prefixIcon: const Icon(Icons.category, color: Color(0xFF78909C)),
        filled: true,
        fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E88E5))),
      ),
    );
  }

  void _showUnitDetails(dynamic unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title: Text(
          unit['unit_name'] ?? 'Unit Details',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', _formatUnitType(unit['unit_type'])),
            _buildDetailRow('Location', unit['location'] ?? 'N/A'),
            _buildDetailRow('Province', unit['province'] ?? 'N/A'),
            _buildDetailRow('District', unit['district'] ?? 'N/A'),
            _buildDetailRow(
                'Commander', unit['commander_name'] ?? 'Not assigned'),
            _buildDetailRow('Phone', unit['contact_phone'] ?? 'N/A'),
            _buildDetailRow('Email', unit['contact_email'] ?? 'N/A'),
            _buildDetailRow(
              'Status',
              unit['is_active'] == true ? 'Active' : 'Inactive',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(color: Color(0xFF78909C)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnitStats(dynamic unit) {
    if (unit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load unit statistics'),
          backgroundColor: Color(0xFFE85C5C),
        ),
      );
      return;
    }

    final unitName = unit['unit_name']?.toString() ?? 'Unknown Unit';
    final firearmCount = int.tryParse(unit['firearm_count']?.toString() ??
            unit['firearms_count']?.toString() ??
            '0') ??
        0;
    final officerCount = int.tryParse(unit['officer_count']?.toString() ??
            unit['officers_count']?.toString() ??
            '0') ??
        0;
    final activeCustody =
        int.tryParse(unit['active_custody']?.toString() ?? '0') ?? 0;
    final pendingApprovals =
        int.tryParse(unit['pending_approvals']?.toString() ?? '0') ?? 0;
    final anomalyCount =
        int.tryParse(unit['anomaly_count']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title: Row(
          children: [
            const Icon(Icons.assessment, color: Color(0xFF1E88E5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$unitName - Statistics',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Firearms',
                      '$firearmCount',
                      Icons.gavel,
                      const Color(0xFF42A5F5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Officers',
                      '$officerCount',
                      Icons.badge,
                      const Color(0xFF3CCB7F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Active Custody',
                      '$activeCustody',
                      Icons.swap_horiz,
                      const Color(0xFF9C27B0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Pending Approvals',
                      '$pendingApprovals',
                      Icons.pending_actions,
                      const Color(0xFFFFC857),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (anomalyCount > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE85C5C).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFFE85C5C)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Color(0xFFE85C5C)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Anomalies Detected',
                              style: TextStyle(
                                color: Color(0xFFE85C5C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$anomalyCount anomalies require investigation',
                              style: const TextStyle(
                                color: Color(0xFF78909C),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Admin Responsibilities Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Responsibilities',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildResponsibilityItem(
                      'Oversee firearm registrations',
                      Icons.check_circle,
                      const Color(0xFF3CCB7F),
                    ),
                    _buildResponsibilityItem(
                      'Review custody transfer approvals',
                      Icons.check_circle,
                      const Color(0xFF3CCB7F),
                    ),
                    _buildResponsibilityItem(
                      'Monitor anomaly alerts',
                      Icons.check_circle,
                      const Color(0xFF3CCB7F),
                    ),
                    _buildResponsibilityItem(
                      'Audit unit activities',
                      Icons.check_circle,
                      const Color(0xFF3CCB7F),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to unit reports
            },
            icon: const Icon(Icons.description, size: 18),
            label: const Text('View Reports'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsibilityItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
