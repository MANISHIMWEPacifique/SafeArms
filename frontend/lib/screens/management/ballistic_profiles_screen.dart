// Ballistic Profiles Screen
// View and manage ballistic profiles for forensics
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ballistic_profile_provider.dart';

class BallisticProfilesScreen extends StatefulWidget {
  const BallisticProfilesScreen({Key? key}) : super(key: key);

  @override
  State<BallisticProfilesScreen> createState() =>
      _BallisticProfilesScreenState();
}

class _BallisticProfilesScreenState extends State<BallisticProfilesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BallisticProfileProvider>().loadProfiles();
      context.read<BallisticProfileProvider>().loadStats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BallisticProfileProvider>(
      builder: (context, provider, child) {
        final stats = provider.stats;

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
                        'Ballistic Profiles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Search and compare firearm ballistic characteristics',
                        style:
                            TextStyle(color: Color(0xFF78909C), fontSize: 14),
                      ),
                    ],
                  ),
                  // Info badge - profiles are created during firearm registration
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF37404F),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4A5568)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.info_outline,
                            color: Color(0xFF78909C), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Profiles created during HQ registration',
                          style: TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Stats Cards - Updated for search/match purpose
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Profiles',
                      '${stats['total'] ?? 0}',
                      Icons.fingerprint,
                      const Color(0xFF1E88E5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'With Rifling Data',
                      '${stats['with_rifling'] ?? 0}',
                      Icons.track_changes,
                      const Color(0xFF42A5F5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'With Firing Pin',
                      '${stats['with_firing_pin'] ?? 0}',
                      Icons.adjust,
                      const Color(0xFF3CCB7F),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'With Ejector/Extractor',
                      '${stats['with_ejector_extractor'] ?? 0}',
                      Icons.compare_arrows,
                      const Color(0xFF78909C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Search
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by serial number, ballistic ID...',
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
                  provider.setSearchQuery(value);
                },
              ),
              const SizedBox(height: 24),

              // Profiles List
              _buildProfilesList(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfilesList(BallisticProfileProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
      );
    }

    final profiles = provider.filteredProfiles;

    if (profiles.isEmpty) {
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
                Icons.fingerprint,
                size: 64,
                color: Color(0xFF78909C),
              ),
              SizedBox(height: 16),
              Text(
                'No ballistic profiles found',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'Register firearms to create ballistic profiles',
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
                    'Profile ID / Firearm',
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
                    'Test Date',
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
                SizedBox(width: 100, child: Text('')),
              ],
            ),
          ),

          // Table Body
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const Divider(
              color: Color(0xFF37404F),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return _buildProfileRow(profile);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(Map<String, dynamic> profile) {
    final status = profile['profile_status'] ?? 'pending';
    final isComplete = status == 'complete' || status == 'verified';

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
                  child: const Icon(
                    Icons.fingerprint,
                    color: Color(0xFF1E88E5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile['ballistic_id'] ?? 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        profile['firearm_serial'] ??
                            profile['firearm_id'] ??
                            'Unknown',
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
          Expanded(
            child: Text(
              profile['firearm_type'] ?? 'N/A',
              style: const TextStyle(color: Color(0xFFB0BEC5)),
            ),
          ),
          Expanded(
            child: Text(
              _formatDate(profile['test_date']),
              style: const TextStyle(color: Color(0xFFB0BEC5)),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isComplete
                    ? const Color(0xFF3CCB7F).withOpacity(0.2)
                    : const Color(0xFFFFC857).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatStatus(status),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isComplete
                      ? const Color(0xFF3CCB7F)
                      : const Color(0xFFFFC857),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, color: Color(0xFF78909C)),
                  onPressed: () => _showProfileDetails(profile),
                  tooltip: 'View Profile',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF78909C)),
                  onPressed: () => _showEditProfileDialog(profile),
                  tooltip: 'Edit Profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final DateTime parsed =
          date is DateTime ? date : DateTime.parse(date.toString());
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (e) {
      return date.toString();
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  void _showAddProfileDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add Profile dialog - coming soon'),
        backgroundColor: Color(0xFF1E88E5),
      ),
    );
  }

  void _showProfileDetails(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title: Row(
          children: [
            const Icon(Icons.fingerprint, color: Color(0xFF1E88E5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ballistic Profile - ${profile['ballistic_id'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailSection('Profile Details', [
                _buildDetailRow('Profile ID', profile['ballistic_id'] ?? 'N/A'),
                _buildDetailRow('Firearm ID', profile['firearm_id'] ?? 'N/A'),
                _buildDetailRow(
                    'Serial Number', profile['firearm_serial'] ?? 'N/A'),
                _buildDetailRow('Test Date', _formatDate(profile['test_date'])),
                _buildDetailRow(
                    'Test Location', profile['test_location'] ?? 'N/A'),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Ballistic Characteristics', [
                _buildDetailRow('Rifling Characteristics',
                    profile['rifling_characteristics'] ?? 'Not recorded'),
                _buildDetailRow('Firing Pin Impression',
                    profile['firing_pin_impression'] ?? 'Not recorded'),
                _buildDetailRow('Ejector Marks',
                    profile['ejector_marks'] ?? 'Not recorded'),
                _buildDetailRow('Extractor Marks',
                    profile['extractor_marks'] ?? 'Not recorded'),
                _buildDetailRow('Chamber Marks',
                    profile['chamber_marks'] ?? 'Not recorded'),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Test Information', [
                _buildDetailRow('Conducted By',
                    profile['test_conducted_by'] ?? 'Not recorded'),
                _buildDetailRow(
                    'Forensic Lab', profile['forensic_lab'] ?? 'Not recorded'),
                _buildDetailRow('Test Ammunition',
                    profile['test_ammunition'] ?? 'Not recorded'),
                _buildDetailRow('Notes', profile['notes'] ?? 'None'),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          // Edit button removed - profiles are immutable after HQ registration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3CCB7F).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: Color(0xFF3CCB7F), size: 14),
                SizedBox(width: 4),
                Text('Read-Only Profile',
                    style: TextStyle(color: Color(0xFF3CCB7F), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1E88E5),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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

  void _showEditProfileDialog(Map<String, dynamic> profile) {
    // Ballistic profiles are immutable after HQ registration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ballistic profiles are read-only after registration'),
        backgroundColor: Color(0xFF78909C),
      ),
    );
  }
}
