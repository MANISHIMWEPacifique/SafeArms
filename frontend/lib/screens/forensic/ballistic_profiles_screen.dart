// Ballistic Profiles Management Screen (Screen 13)
// SafeArms Frontend - Forensic database with split-screen layout

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ballistic_profile_provider.dart';
import '../../providers/auth_provider.dart';

class BallisticProfilesScreen extends StatefulWidget {
  const BallisticProfilesScreen({Key? key}) : super(key: key);

  @override
  State<BallisticProfilesScreen> createState() =>
      _BallisticProfilesScreenState();
}

class _BallisticProfilesScreenState extends State<BallisticProfilesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String? _selectedProfileId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BallisticProfileProvider>().loadProfiles();
      context.read<BallisticProfileProvider>().loadStats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<BallisticProfileProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isHQCommander = authProvider.userRole == 'hq_firearm_commander';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                // LEFT PANEL - Profile List (40%)
                Expanded(
                  flex: 4,
                  child: _buildLeftPanel(profileProvider, isHQCommander),
                ),
                Container(width: 1, color: const Color(0xFF37404F)),
                // RIGHT PANEL - Profile Details (60%)
                Expanded(
                  flex: 6,
                  child: _buildRightPanel(profileProvider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(
      BallisticProfileProvider provider, bool isHQCommander) {
    return Container(
      color: const Color(0xFF252A3A),
      child: Column(
        children: [
          _buildLeftPanelHeader(isHQCommander),
          _buildStatsBar(provider),
          _buildFilterButtons(provider),
          Expanded(child: _buildProfileList(provider)),
        ],
      ),
    );
  }

  Widget _buildLeftPanelHeader(bool isHQCommander) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ballistic Profiles',
            style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search and compare firearm ballistic characteristics',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
          const SizedBox(height: 8),
          // Read-only indicator for forensic analysts
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1565C0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility, color: Color(0xFF42A5F5), size: 16),
                SizedBox(width: 8),
                Text(
                  'Read-Only Access • Search & Compare Only',
                  style: TextStyle(
                    color: Color(0xFF42A5F5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                context.read<BallisticProfileProvider>().setSearchQuery(value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by serial number, manufacturer...',
              hintStyle: const TextStyle(color: Color(0xFF78909C)),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF78909C), size: 20),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(BallisticProfileProvider provider) {
    final stats = provider.stats;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.storage,
              label: 'Total Profiles',
              value: '${provider.profiles.length}',
              color: const Color(0xFF42A5F5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.fingerprint,
              label: 'With Rifling',
              value: '${stats['with_rifling'] ?? 0}',
              color: const Color(0xFF66BB6A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.adjust,
              label: 'With Firing Pin',
              value: '${stats['with_firing_pin'] ?? 0}',
              color: const Color(0xFF1E88E5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons(BallisticProfileProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildFilterChip('All', 'all', provider),
          _buildFilterChip('Pistols', 'pistol', provider),
          _buildFilterChip('Rifles', 'rifle', provider),
          _buildFilterChip('Shotguns', 'shotgun', provider),
          _buildFilterChip('SMGs', 'submachine_gun', provider),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label, String value, BallisticProfileProvider provider) {
    final isSelected = provider.firearmTypeFilter == value;
    return InkWell(
      onTap: () => provider.setFirearmTypeFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E88E5) : const Color(0xFF2A3040),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1E88E5) : const Color(0xFF37404F),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFB0BEC5),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileList(BallisticProfileProvider provider) {
    if (provider.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
    }

    final profiles = provider.filteredProfiles;

    if (profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.science_outlined, size: 64, color: Color(0xFF78909C)),
            SizedBox(height: 16),
            Text(
              'No ballistic profiles yet',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: profiles.length,
      itemBuilder: (context, index) => _buildProfileCard(profiles[index]),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final profileId = profile['ballistic_profile_id'] ?? '';
    final isSelected = profileId == _selectedProfileId;

    return InkWell(
      onTap: () {
        setState(() => _selectedProfileId = profileId);
        context.read<BallisticProfileProvider>().selectProfile(profileId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3040),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1E88E5) : const Color(0xFF37404F),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
                      blurRadius: 8)
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A5F),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getFirearmIcon(profile['firearm_type']),
                color: const Color(0xFF42A5F5),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile['firearm_serial'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile['manufacturer']} ${profile['model']}',
                    style:
                        const TextStyle(color: Color(0xFF78909C), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          profile['caliber'] ?? '',
                          style: const TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on,
                          size: 12, color: Color(0xFF78909C)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          profile['unit_name'] ?? 'No Unit',
                          style: const TextStyle(
                              color: Color(0xFF78909C), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF78909C)),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel(BallisticProfileProvider provider) {
    if (provider.selectedProfile == null) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildProfileHeader(provider.selectedProfile!),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBallisticCharTab(provider.selectedProfile!),
              _buildForensicAnalysisTab(provider.selectedProfile!),
              _buildCustodyHistoryTab(provider.selectedProfile!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.biotech, size: 96, color: Color(0xFF78909C)),
          SizedBox(height: 24),
          Text(
            'Select a firearm to view ballistic profile',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'View ballistic characteristics for search and matching',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFF2A3040),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getFirearmIcon(profile['firearm_type']),
              color: const Color(0xFF42A5F5),
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['firearm_serial'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile['manufacturer']} ${profile['model']}',
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildBadge(
                        '${profile['firearm_type']}', const Color(0xFF1E88E5)),
                    const SizedBox(width: 8),
                    _buildBadge(
                        '${profile['caliber']}', const Color(0xFF42A5F5)),
                    const SizedBox(width: 8),
                    _buildBadge('${profile['registration_level']}',
                        const Color(0xFF3CCB7F)),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Edit button removed - profiles are read-only after HQ registration
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3CCB7F).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: Color(0xFF3CCB7F), size: 14),
                    SizedBox(width: 4),
                    Text('Read-Only',
                        style:
                            TextStyle(color: Color(0xFF3CCB7F), fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.print, color: Color(0xFFB0BEC5)),
                onPressed: () {
                  // Print report
                },
                tooltip: 'Print Report',
              ),
              IconButton(
                icon: const Icon(Icons.download, color: Color(0xFFB0BEC5)),
                onPressed: () {
                  // Export data
                },
                tooltip: 'Export Data',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF1E88E5),
        indicatorWeight: 3,
        labelColor: const Color(0xFF1E88E5),
        unselectedLabelColor: const Color(0xFF78909C),
        tabs: const [
          Tab(text: 'Ballistic Characteristics'),
          Tab(text: 'Registration Details'),
          Tab(text: 'Custody History'),
        ],
      ),
    );
  }

  Widget _buildBallisticCharTab(Map<String, dynamic> profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildCharCard('Barrel Rifling Pattern',
              profile['rifling_characteristics'], Icons.sync),
          _buildCharCard('Firing Pin Impression',
              profile['firing_pin_impression'], Icons.circle),
          _buildCharCard('Breech Face Marking', profile['breech_face_marking'],
              Icons.grid_3x3),
          _buildCharCard('Ejector Mark Pattern',
              profile['ejector_mark_pattern'], Icons.arrow_forward),
          _buildCharCard('Extractor Mark Pattern',
              profile['extractor_mark_pattern'], Icons.arrow_back),
          _buildCharCard('Cartridge Case Profile',
              profile['cartridge_case_profile'], Icons.filter_1),
          _buildCharCard(
              'Land & Groove Count',
              profile['land_groove_count']?.toString(),
              Icons.format_list_numbered),
          _buildCharCard('Twist Direction', profile['twist_direction'],
              Icons.rotate_right),
          _buildCharCard('Twist Rate', profile['twist_rate'], Icons.speed),
        ],
      ),
    );
  }

  Widget _buildCharCard(String label, dynamic value, IconData icon) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF42A5F5), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style:
                      const TextStyle(color: Color(0xFF78909C), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value?.toString() ?? 'Not specified',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildForensicAnalysisTab(Map<String, dynamic> profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Registration Metadata',
            style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Registration Date', _formatDate(profile['test_date'])),
          _buildInfoRow(
              'Recorded By',
              profile['analyzed_by'] ??
                  profile['test_conducted_by'] ??
                  'Not specified'),
          _buildInfoRow('Registration Location',
              profile['test_location'] ?? 'Not specified'),
          const SizedBox(height: 24),
          const Text(
            'Additional Notes',
            style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: Text(
              profile['analysis_notes'] ??
                  profile['notes'] ??
                  'No notes recorded',
              style: const TextStyle(
                  color: Color(0xFFB0BEC5), fontSize: 14, height: 1.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quality Assessment',
            style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildQualityIndicator(profile['quality_assessment'] ?? 'Good'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityIndicator(String quality) {
    Color color;
    switch (quality.toLowerCase()) {
      case 'excellent':
        color = const Color(0xFF3CCB7F);
        break;
      case 'good':
        color = const Color(0xFF42A5F5);
        break;
      case 'fair':
        color = const Color(0xFFFFC857);
        break;
      default:
        color = const Color(0xFF78909C);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            'Profile Quality: ${quality.toUpperCase()}',
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCustodyHistoryTab(Map<String, dynamic> profile) {
    return const Center(
      child: Text(
        'Custody history will be displayed here',
        style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
      ),
    );
  }

  IconData _getFirearmIcon(dynamic type) {
    final typeStr = type?.toString() ?? '';
    if (typeStr.contains('pistol')) return Icons.sports_martial_arts;
    if (typeStr.contains('rifle')) return Icons.yard;
    if (typeStr.contains('shotgun')) return Icons.wifi_protected_setup;
    return Icons.hardware;
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not specified';
    try {
      final dt = DateTime.parse(date.toString());
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
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }
}
