// System Settings Screen (Screen 14)
// SafeArms Frontend - Admin-only system configuration interface

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({Key? key}) : super(key: key);

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  String _selectedMenu = 'general';

  // General Settings state
  final TextEditingController _platformNameController =
      TextEditingController(text: 'SafeArms');
  final TextEditingController _organizationController =
      TextEditingController(text: 'Rwanda National Police');
  String _timeZone = 'Africa/Kigali (CAT, UTC+2)';
  String _dateFormat = 'DD/MM/YYYY';
  String _timeFormat = '24-hour';
  int _sessionTimeout = 30;
  bool _concurrentSessions = false;
  int _rememberMeDuration = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadSettings();
      context.read<SettingsProvider>().loadSystemHealth();
    });
  }

  @override
  void dispose() {
    _platformNameController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    // Show loading indicator while settings are being fetched
    if (settingsProvider.isLoading) {
      return Container(
        color: const Color(0xFF1A1F2E),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
        ),
      );
    }

    // Show error message if there's an error
    if (settingsProvider.errorMessage != null) {
      return Container(
        color: const Color(0xFF1A1F2E),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFE85C5C), size: 64),
              const SizedBox(height: 16),
              const Text(
                'Failed to load settings',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                settingsProvider.errorMessage!,
                style: const TextStyle(color: Color(0xFF78909C)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  settingsProvider.loadSettings();
                  settingsProvider.loadSystemHealth();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1A1F2E),
      child: Row(
        children: [
          // LEFT SIDE MENU (25%)
          Expanded(
            flex: 25,
            child: _buildSideMenu(),
          ),
          Container(width: 1, color: const Color(0xFF37404F)),
          // MAIN CONTENT AREA (75%)
          Expanded(
            flex: 75,
            child: _buildContentArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildSideMenu() {
    return Container(
      color: const Color(0xFF252A3A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Settings',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Platform Configuration',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Admin Access',
                    style: TextStyle(
                        color: Color(0xFF1E88E5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF37404F), height: 1),
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildMenuItem('general', Icons.settings, 'General Settings'),
                _buildMenuItem(
                    'security', Icons.shield, 'Security & Authentication'),
                _buildMenuItem('ml', Icons.psychology, 'ML.js Configuration'),
                _buildMenuItem('email', Icons.email, 'Email Settings'),
                _buildMenuItem('audit', Icons.list_alt, 'Audit Logs'),
                _buildMenuItem('health', Icons.favorite, 'System Health'),
                _buildMenuItem('backup', Icons.backup, 'Backup & Recovery'),
                _buildMenuItem('permissions', Icons.people, 'User Permissions'),
                _buildMenuItem(
                    'notifications', Icons.notifications, 'Notifications'),
                _buildMenuItem('advanced', Icons.tune, 'Advanced Settings'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String id, IconData icon, String label) {
    final isActive = _selectedMenu == id;
    return InkWell(
      onTap: () => setState(() => _selectedMenu = id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1E88E5).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isActive ? const Color(0xFF1E88E5) : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  isActive ? const Color(0xFF1E88E5) : const Color(0xFF78909C),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF1E88E5)
                    : const Color(0xFFB0BEC5),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    switch (_selectedMenu) {
      case 'general':
        return _buildGeneralSettings();
      case 'security':
        return _buildSecuritySettings();
      case 'ml':
        return _buildMLConfiguration();
      case 'audit':
        return _buildAuditLogs();
      case 'health':
        return _buildSystemHealth();
      default:
        return _buildComingSoon();
    }
  }

  Widget _buildGeneralSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'General Settings',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Configure platform-wide settings',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  // Save changes
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Save Changes'),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Platform Information
          _buildSettingsCard(
            'Platform Information',
            Column(
              children: [
                _buildTextField('Platform Name', _platformNameController),
                const SizedBox(height: 16),
                _buildTextField('Organization', _organizationController),
                const SizedBox(height: 16),
                _buildReadOnlyField('Installation ID', 'RNP-SAFE-2024-001'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildReadOnlyField('Version', 'v1.2.3')),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Environment',
                              style: TextStyle(
                                  color: Color(0xFFB0BEC5), fontSize: 13)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3CCB7F).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Production',
                              style: TextStyle(
                                  color: Color(0xFF3CCB7F),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Regional Settings
          _buildSettingsCard(
            'Regional Settings',
            Column(
              children: [
                _buildDropdownFieldSafe(
                    'Time Zone',
                    _timeZone,
                    [
                      'Africa/Kigali (CAT, UTC+2)',
                      'UTC',
                      'America/New_York',
                    ],
                    (value) => setState(() => _timeZone = value!)),
                const SizedBox(height: 16),
                _buildRadioGroup(
                    'Date Format',
                    _dateFormat,
                    [
                      'DD/MM/YYYY',
                      'MM/DD/YYYY',
                      'YYYY-MM-DD',
                    ],
                    (value) => setState(() => _dateFormat = value!)),
                const SizedBox(height: 16),
                _buildRadioGroup(
                    'Time Format',
                    _timeFormat,
                    [
                      '24-hour',
                      '12-hour',
                    ],
                    (value) => setState(() => _timeFormat = value!)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Session Management
          _buildSettingsCard(
            'Session Management',
            Column(
              children: [
                _buildNumberField(
                  'Session Timeout',
                  _sessionTimeout,
                  (value) => setState(() => _sessionTimeout = value),
                  helperText:
                      'Users will be logged out after this period of inactivity',
                  unit: 'minutes',
                ),
                const SizedBox(height: 16),
                _buildToggleField(
                  'Concurrent Sessions',
                  _concurrentSessions,
                  (value) => setState(() => _concurrentSessions = value),
                  'Allow users to login from multiple devices',
                ),
                const SizedBox(height: 16),
                _buildNumberField(
                  'Remember Me Duration',
                  _rememberMeDuration,
                  (value) => setState(() => _rememberMeDuration = value),
                  unit: 'days',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security & Authentication',
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC857).withOpacity(0.1),
              border: Border.all(color: const Color(0xFFFFC857)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Icon(Icons.warning, color: Color(0xFFFFC857), size: 20),
                SizedBox(width: 12),
                Text(
                  'Changes to security settings require immediate effect',
                  style: TextStyle(color: Color(0xFFFFC857), fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSettingsCard(
            'Password Policy',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNumberField('Minimum Length', 8, (v) {}),
                const SizedBox(height: 12),
                _buildCheckboxField('Require Uppercase Letters', true, (v) {}),
                _buildCheckboxField('Require Lowercase Letters', true, (v) {}),
                _buildCheckboxField('Require Numbers', true, (v) {}),
                _buildCheckboxField('Require Special Characters', true, (v) {}),
                const SizedBox(height: 16),
                _buildNumberField('Password Expiry', 90, (v) {}, unit: 'days'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSettingsCard(
            'Two-Factor Authentication (Email OTP)',
            Column(
              children: [
                _buildToggleField('Enable 2FA', true, (v) {},
                    'Email OTP verification for all users'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildNumberField('OTP Code Length', 6, (v) {},
                            unit: 'digits')),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildNumberField('OTP Validity', 10, (v) {},
                            unit: 'minutes')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child:
                            _buildNumberField('Max OTP Attempts', 3, (v) {})),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildNumberField('Lockout Duration', 15, (v) {},
                            unit: 'minutes')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMLConfiguration() {
    final settingsProvider = context.watch<SettingsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'ML.js Anomaly Detection Configuration',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Configure machine learning parameters for custody anomaly detection',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3CCB7F).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle,
                        color: Color(0xFF3CCB7F), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'ML Engine: Active',
                      style: TextStyle(
                          color: Color(0xFF3CCB7F),
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Model Status Cards
          Row(
            children: [
              Expanded(
                  child: _buildStatusCard('Active Model', 'v1.2.3',
                      'Trained: Dec 8, 2025', Icons.psychology)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatusCard('Detection Status', 'Operational',
                      '0 errors in 24h', Icons.check_circle)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatusCard('Performance', '0.23s',
                      'Avg detection latency', Icons.speed)),
            ],
          ),
          const SizedBox(height: 24),

          _buildSettingsCard(
            'Detection Thresholds',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Anomaly Detection Threshold',
                    style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14)),
                Slider(
                  value: 0.35,
                  min: 0.0,
                  max: 1.0,
                  activeColor: const Color(0xFF1E88E5),
                  onChanged: (value) {},
                ),
                const Text(
                  'Lower = more sensitive, Higher = fewer alerts',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: settingsProvider.isSaving
                    ? null
                    : () {
                        context.read<SettingsProvider>().trainMLModel();
                      },
                icon: settingsProvider.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('Train Model Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {},
                child: const Text('View Training History'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogs() {
    return const Center(
      child: Text(
        'Audit Logs interface coming soon',
        style: TextStyle(color: Color(0xFF78909C), fontSize: 16),
      ),
    );
  }

  Widget _buildSystemHealth() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'System Health Dashboard',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3CCB7F).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle,
                        color: Color(0xFF3CCB7F), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'All Systems Operational',
                      style: TextStyle(
                          color: Color(0xFF3CCB7F),
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildHealthCard(
                  'Database',
                  'Healthy',
                  '42/100 active connections',
                  Icons.storage,
                  const Color(0xFF3CCB7F)),
              _buildHealthCard('ML.js Engine', 'Running', 'v1.2.3 - 0 pending',
                  Icons.psychology, const Color(0xFF1E88E5)),
              _buildHealthCard('Email Service', 'Connected', '148 sent (24h)',
                  Icons.email, const Color(0xFF42A5F5)),
              _buildHealthCard('API Performance', 'Optimal',
                  '123ms avg response', Icons.api, const Color(0xFF3CCB7F)),
              _buildHealthCard('Storage', 'Healthy', '2.4 GB database size',
                  Icons.storage, const Color(0xFF1E88E5)),
              _buildHealthCard('Active Sessions', '87 users', 'Peak: 142 today',
                  Icons.people, const Color(0xFF42A5F5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: Color(0xFF78909C)),
          SizedBox(height: 16),
          Text(
            'Coming Soon',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'This section is under development',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Helper widgets...
  Widget _buildSettingsCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF2A3040),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF37404F)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: Text(
            value,
            style: const TextStyle(
                color: Color(0xFF78909C), fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  // Safe dropdown that handles value not in items list
  Widget _buildDropdownFieldSafe(String label, String value, List<String> items,
      Function(String?) onChanged) {
    // Ensure the current value is in the items list, otherwise use first item
    final safeValue = items.contains(value) ? value : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              dropdownColor: const Color(0xFF2A3040),
              style: const TextStyle(color: Colors.white),
              items: items
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioGroup(String label, String value, List<String> options,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
        const SizedBox(height: 8),
        ...options
            .map((option) => RadioListTile<String>(
                  value: option,
                  groupValue: value,
                  onChanged: onChanged,
                  title: Text(option,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14)),
                  activeColor: const Color(0xFF1E88E5),
                ))
            .toList(),
      ],
    );
  }

  Widget _buildNumberField(String label, int value, Function(int) onChanged,
      {String? helperText, String? unit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3040),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF37404F)),
                ),
                child:
                    Text('$value', style: const TextStyle(color: Colors.white)),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 12),
              Text(unit,
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14)),
            ],
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(helperText,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildToggleField(
      String label, bool value, Function(bool) onChanged, String? helperText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              if (helperText != null)
                Text(helperText,
                    style: const TextStyle(
                        color: Color(0xFF78909C), fontSize: 12)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF1E88E5),
        ),
      ],
    );
  }

  Widget _buildCheckboxField(
      String label, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      activeColor: const Color(0xFF1E88E5),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildStatusCard(
      String title, String value, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1E88E5), size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard(
      String title, String status, String details, IconData icon, Color color) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            details,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
