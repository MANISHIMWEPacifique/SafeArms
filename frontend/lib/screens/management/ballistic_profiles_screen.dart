// Ballistic Profiles Screen
// View and manage ballistic profiles for forensics
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firearm_provider.dart';

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
      context.read<FirearmProvider>().loadFirearms();
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
                    'Ballistic Profiles',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View and manage forensic ballistic profiles',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddProfileDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Profile'),
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

          // Stats Cards
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('Total Profiles', '0',
                      Icons.fingerprint, const Color(0xFF1E88E5))),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatCard('Pending Analysis', '0', Icons.pending,
                      const Color(0xFFFFC857))),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatCard('Matched Cases', '0',
                      Icons.check_circle, const Color(0xFF3CCB7F))),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatCard('No Match', '0', Icons.help_outline,
                      const Color(0xFF78909C))),
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
              setState(() {});
            },
          ),
          const SizedBox(height: 24),

          // Profiles List
          Consumer<FirearmProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
                );
              }

              final firearms = provider.firearms;

              if (firearms.isEmpty) {
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
                              'Firearm',
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
                              'Caliber',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Profile Status',
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
                      itemCount: firearms.length,
                      separatorBuilder: (_, __) => const Divider(
                        color: Color(0xFF37404F),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final firearm = firearms[index];
                        return _buildProfileRow(firearm);
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

  Widget _buildProfileRow(dynamic firearm) {
    final hasProfile = firearm.ballisticId != null;

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
                    Icons.gps_fixed,
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
                        firearm.serialNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${firearm.manufacturer} ${firearm.model}',
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
              firearm.firearmType,
              style: const TextStyle(color: Color(0xFFB0BEC5)),
            ),
          ),
          Expanded(
            child: Text(
              firearm.caliber,
              style: const TextStyle(color: Color(0xFFB0BEC5)),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: hasProfile
                    ? const Color(0xFF3CCB7F).withOpacity(0.2)
                    : const Color(0xFFFFC857).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hasProfile ? 'Complete' : 'Pending',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hasProfile
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
                  onPressed: () => _showProfileDetails(firearm),
                  tooltip: 'View Profile',
                ),
                IconButton(
                  icon: Icon(
                    hasProfile ? Icons.edit : Icons.add,
                    color: const Color(0xFF78909C),
                  ),
                  onPressed: () => hasProfile
                      ? _showEditProfileDialog(firearm)
                      : _showAddProfileForFirearm(firearm),
                  tooltip: hasProfile ? 'Edit Profile' : 'Add Profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProfileDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add Profile dialog - coming soon'),
        backgroundColor: Color(0xFF1E88E5),
      ),
    );
  }

  void _showProfileDetails(dynamic firearm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title: Row(
          children: [
            const Icon(Icons.fingerprint, color: Color(0xFF1E88E5)),
            const SizedBox(width: 8),
            Text(
              'Ballistic Profile - ${firearm.serialNumber}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailSection('Firearm Details', [
              _buildDetailRow('Serial Number', firearm.serialNumber),
              _buildDetailRow('Manufacturer', firearm.manufacturer),
              _buildDetailRow('Model', firearm.model),
              _buildDetailRow('Type', firearm.firearmType),
              _buildDetailRow('Caliber', firearm.caliber),
            ]),
            const SizedBox(height: 16),
            _buildDetailSection('Ballistic Characteristics', [
              _buildDetailRow(
                  'Profile ID', firearm.ballisticId ?? 'Not recorded'),
              _buildDetailRow('Rifling Pattern', 'Not recorded'),
              _buildDetailRow('Firing Pin', 'Not recorded'),
              _buildDetailRow('Breech Face', 'Not recorded'),
            ]),
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
              _showEditProfileDialog(firearm);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
            ),
            child: const Text('Edit Profile'),
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
            width: 120,
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

  void _showEditProfileDialog(dynamic firearm) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit profile for ${firearm.serialNumber} - coming soon'),
        backgroundColor: Color(0xFF1E88E5),
      ),
    );
  }

  void _showAddProfileForFirearm(dynamic firearm) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add profile for ${firearm.serialNumber} - coming soon'),
        backgroundColor: Color(0xFF1E88E5),
      ),
    );
  }
}
