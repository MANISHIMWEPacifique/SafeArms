// Forensic Search Screen
// Search firearms and custody records for forensic analysis

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firearm_provider.dart';

class ForensicSearchScreen extends StatefulWidget {
  const ForensicSearchScreen({super.key});

  @override
  State<ForensicSearchScreen> createState() => _ForensicSearchScreenState();
}

class _ForensicSearchScreenState extends State<ForensicSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchType = 'serial_number';

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
          const Text(
            'Forensic Search',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search firearms by serial number, ballistic profile, or custody records',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
          const SizedBox(height: 32),

          // Search Box
          Container(
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
                  'Search Criteria',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Search Type Selection
                Row(
                  children: [
                    _buildSearchTypeChip('Serial Number', 'serial_number'),
                    const SizedBox(width: 8),
                    _buildSearchTypeChip('Ballistic ID', 'ballistic_id'),
                    const SizedBox(width: 8),
                    _buildSearchTypeChip('Officer', 'officer'),
                    const SizedBox(width: 8),
                    _buildSearchTypeChip('Case Number', 'case_number'),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _getSearchHint(),
                          hintStyle: const TextStyle(color: Color(0xFF78909C)),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF78909C),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1A1F2E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF37404F),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF37404F),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E88E5),
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _performSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
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
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Search Results
          _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildSearchTypeChip(String label, String value) {
    final isSelected = _searchType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _searchType = value;
        });
      },
      selectedColor: const Color(0xFF1E88E5),
      backgroundColor: const Color(0xFF1A1F2E),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFFB0BEC5),
      ),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFF37404F),
      ),
    );
  }

  String _getSearchHint() {
    switch (_searchType) {
      case 'serial_number':
        return 'Enter firearm serial number...';
      case 'ballistic_id':
        return 'Enter ballistic profile ID...';
      case 'officer':
        return 'Enter officer name or number...';
      case 'case_number':
        return 'Enter case reference number...';
      default:
        return 'Enter search term...';
    }
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Load firearms with search
    final firearmProvider = Provider.of<FirearmProvider>(
      context,
      listen: false,
    );
    firearmProvider.loadFirearms();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching for "$query" in $_searchType...'),
        backgroundColor: const Color(0xFF1E88E5),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Consumer<FirearmProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
          );
        }

        if (provider.firearms.isEmpty) {
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
                  Icon(Icons.search, size: 64, color: Color(0xFF78909C)),
                  SizedBox(height: 16),
                  Text(
                    'Enter search criteria above',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Search by serial number, ballistic ID, officer, or case number',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Results (${provider.firearms.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Color(0xFF37404F), height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.firearms.length,
                separatorBuilder: (_, __) => const Divider(
                  color: Color(0xFF37404F),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final firearm = provider.firearms[index];
                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.gps_fixed,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                    title: Text(
                      firearm.serialNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${firearm.manufacturer} ${firearm.model} • ${firearm.firearmType}',
                      style: const TextStyle(color: Color(0xFF78909C)),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(firearm.currentStatus)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        firearm.currentStatus.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(firearm.currentStatus),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () {
                      // Show firearm details dialog
                      _showFirearmDetails(firearm);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF3CCB7F);
      case 'in_custody':
        return const Color(0xFF1E88E5);
      case 'maintenance':
        return const Color(0xFFFFC857);
      case 'lost':
      case 'stolen':
        return const Color(0xFFE85C5C);
      default:
        return const Color(0xFF78909C);
    }
  }

  void _showFirearmDetails(dynamic firearm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title: Text(
          firearm.serialNumber,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Manufacturer', firearm.manufacturer),
            _buildDetailRow('Model', firearm.model),
            _buildDetailRow('Type', firearm.firearmType),
            _buildDetailRow('Caliber', firearm.caliber),
            _buildDetailRow('Status', firearm.currentStatus),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to full custody history
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
            ),
            child: const Text('View Custody History'),
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
