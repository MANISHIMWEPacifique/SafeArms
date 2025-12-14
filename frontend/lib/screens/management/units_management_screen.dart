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
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF37404F)),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Unit Name',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Type',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Location',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Commander',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Status',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 80, child: Text('')),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getUnitIcon(unit['unit_type']),
                    color: const Color(0xFF1E88E5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    unit['unit_name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getTypeColor(unit['unit_type']).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatUnitType(unit['unit_type']),
                style: TextStyle(
                  color: _getTypeColor(unit['unit_type']),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${unit['district'] ?? ''}, ${unit['province'] ?? ''}',
              style: const TextStyle(color: Color(0xFFB0BEC5)),
            ),
          ),
          Expanded(
            child: Text(
              unit['commander_name'] ?? 'Not assigned',
              style: const TextStyle(color: Color(0xFFB0BEC5)),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: unit['is_active'] == true
                    ? const Color(0xFF3CCB7F).withOpacity(0.2)
                    : const Color(0xFFE85C5C).withOpacity(0.2),
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
                  icon: const Icon(Icons.edit, color: Color(0xFF78909C)),
                  onPressed: () => _showEditUnitDialog(unit),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.visibility, color: Color(0xFF78909C)),
                  onPressed: () => _showUnitDetails(unit),
                  tooltip: 'View Details',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add Unit dialog - coming soon'),
        backgroundColor: Color(0xFF1E88E5),
      ),
    );
  }

  void _showEditUnitDialog(dynamic unit) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit ${unit['unit_name']} - coming soon'),
        backgroundColor: Color(0xFF1E88E5),
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
}
