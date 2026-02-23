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
                      const Color(0xFF1E88E5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'With Firing Pin',
                      '${stats['with_firing_pin'] ?? 0}',
                      Icons.adjust,
                      const Color(0xFF1E88E5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'With Ejector/Extractor',
                      '${stats['with_ejector_extractor'] ?? 0}',
                      Icons.compare_arrows,
                      const Color(0xFF1E88E5),
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
                        profile['serial_number'] ??
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
                    ? const Color(0xFF3CCB7F).withValues(alpha: 0.2)
                    : const Color(0xFFFFC857).withValues(alpha: 0.2),
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

  void _showProfileDetails(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Material(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Container(
            width: 600,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF252A3A),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1F2E),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                        ),
                        child: const Icon(Icons.fingerprint,
                            color: Color(0xFF1E88E5), size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ballistic Profile #${profile['ballistic_id'] ?? 'N/A'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Serial: ${profile['serial_number'] ?? 'N/A'}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3CCB7F).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock,
                                color: Color(0xFF3CCB7F), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'IMMUTABLE',
                              style: TextStyle(
                                color: Color(0xFF3CCB7F),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection(
                            'Profile Details', Icons.info_outline, [
                          _buildDetailField('Profile ID',
                              profile['ballistic_id']?.toString() ?? 'N/A',
                              icon: Icons.tag),
                          _buildDetailField('Firearm ID',
                              profile['firearm_id']?.toString() ?? 'N/A',
                              icon: Icons.gps_fixed),
                          _buildDetailField('Serial Number',
                              profile['serial_number'] ?? 'N/A',
                              icon: Icons.confirmation_number),
                          _buildDetailField(
                              'Test Date', _formatDate(profile['test_date']),
                              icon: Icons.calendar_today),
                          _buildDetailField('Test Location',
                              profile['test_location'] ?? 'N/A',
                              icon: Icons.location_on),
                        ]),
                        const SizedBox(height: 20),
                        _buildDetailSection(
                            'Ballistic Characteristics', Icons.track_changes, [
                          _buildDetailField(
                              'Rifling Characteristics',
                              profile['rifling_characteristics'] ??
                                  'Not recorded',
                              icon: Icons.track_changes),
                          _buildDetailField(
                              'Firing Pin Impression',
                              profile['firing_pin_impression'] ??
                                  'Not recorded',
                              icon: Icons.radio_button_checked),
                          _buildDetailField('Ejector Marks',
                              profile['ejector_marks'] ?? 'Not recorded',
                              icon: Icons.arrow_forward),
                          _buildDetailField('Extractor Marks',
                              profile['extractor_marks'] ?? 'Not recorded',
                              icon: Icons.arrow_back),
                          _buildDetailField('Chamber Marks',
                              profile['chamber_marks'] ?? 'Not recorded',
                              icon: Icons.circle),
                        ]),
                        const SizedBox(height: 20),
                        _buildDetailSection('Test Information', Icons.science, [
                          _buildDetailField('Conducted By',
                              profile['test_conducted_by'] ?? 'Not recorded',
                              icon: Icons.person),
                          _buildDetailField('Forensic Lab',
                              profile['forensic_lab'] ?? 'Not recorded',
                              icon: Icons.biotech),
                          _buildDetailField('Test Ammunition',
                              profile['test_ammunition'] ?? 'Not recorded',
                              icon: Icons.inventory_2),
                          if (profile['notes'] != null &&
                              profile['notes'].toString().isNotEmpty)
                            _buildDetailField('Notes', profile['notes'],
                                icon: Icons.notes),
                        ]),
                      ],
                    ),
                  ),
                ),
                // Action bar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1F2E),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero),
                        ),
                        child: const Text('Close',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(
      String title, IconData sectionIcon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sectionIcon, color: const Color(0xFF1E88E5), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailField(String label, String value, {IconData? icon}) {
    final hasValue =
        value != 'Not recorded' && value != 'N/A' && value != 'None';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: hasValue ? Colors.white : const Color(0xFF546E7A),
                    fontSize: 14,
                  ),
                ),
              ],
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
