// System Settings Screen
// SafeArms Frontend — Admin-only, SharedPreferences-backed configuration
// Simple single-page layout

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/delete_confirmation_dialog.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({Key? key}) : super(key: key);

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadSettings();
      context.read<SettingsProvider>().loadMLStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();

    if (sp.isLoading) {
      return Container(
        color: const Color(0xFF1A1F2E),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1A1F2E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    const Icon(Icons.settings,
                        color: Color(0xFF1E88E5), size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('System Settings',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Preferences are saved automatically',
                              style: TextStyle(
                                  color: Color(0xFF78909C), fontSize: 13)),
                        ],
                      ),
                    ),
                    _resetButton(sp),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Display ──
                _sectionLabel('Display'),
                const SizedBox(height: 12),
                _card(Column(children: [
                  _dropdownRow(
                    'Date Format',
                    sp.dateFormat,
                    ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'],
                    (v) => sp.setDateFormat(v!),
                  ),
                  const Divider(color: Color(0xFF37404F), height: 28),
                  _dropdownRow(
                    'Time Format',
                    sp.timeFormat,
                    ['24-hour', '12-hour'],
                    (v) => sp.setTimeFormat(v!),
                  ),
                  const Divider(color: Color(0xFF37404F), height: 28),
                  _dropdownRow(
                    'Items Per Page',
                    sp.itemsPerPage.toString(),
                    ['10', '25', '50', '100'],
                    (v) => sp.setItemsPerPage(int.parse(v!)),
                  ),
                ])),
                const SizedBox(height: 28),

                // ── Security ──
                _sectionLabel('Security'),
                const SizedBox(height: 12),
                _card(Column(children: [
                  _toggleRow(
                    'Require Two-Factor Authentication',
                    sp.enforce2FA,
                    (v) => sp.setEnforce2FA(v),
                    subtitle: 'Email OTP verification on every login',
                  ),
                  const Divider(color: Color(0xFF37404F), height: 28),
                  _sliderRow(
                    'OTP Validity',
                    sp.otpValidityMinutes.toDouble(),
                    1,
                    15,
                    14,
                    (v) => sp.setOtpValidityMinutes(v.round()),
                    valueLabel: '${sp.otpValidityMinutes} min',
                  ),
                  const Divider(color: Color(0xFF37404F), height: 28),
                  _sliderRow(
                    'Max OTP Attempts',
                    sp.maxOtpAttempts.toDouble(),
                    1,
                    10,
                    9,
                    (v) => sp.setMaxOtpAttempts(v.round()),
                    valueLabel: '${sp.maxOtpAttempts}',
                    helperText:
                        'Account locked after this many failed attempts',
                  ),
                  const Divider(color: Color(0xFF37404F), height: 28),
                  _sliderRow(
                    'Minimum Password Length',
                    sp.minPasswordLength.toDouble(),
                    6,
                    16,
                    10,
                    (v) => sp.setMinPasswordLength(v.round()),
                    valueLabel: '${sp.minPasswordLength} characters',
                  ),
                  const Divider(color: Color(0xFF37404F), height: 28),
                  _sliderRow(
                    'Session Timeout',
                    sp.sessionTimeout.toDouble(),
                    5,
                    120,
                    23,
                    (v) => sp.setSessionTimeout(v.round()),
                    valueLabel: '${sp.sessionTimeout} min',
                    helperText: 'Auto-logout after this period of inactivity',
                  ),
                ])),
                const SizedBox(height: 28),

                // ── Anomaly Detection ──
                _sectionLabel('ANOMALY DETECTION'),
                const SizedBox(height: 12),
                _buildAnomalyDetectionCard(sp),
                const SizedBox(height: 28),

                // ── About ──
                _sectionLabel('About'),
                const SizedBox(height: 12),
                _card(Column(children: [
                  _infoRow('Platform', 'SafeArms v1.0.0'),
                  const Divider(color: Color(0xFF37404F), height: 28),
                  _infoRow('Organization', 'Rwanda National Police'),
                  const Divider(color: Color(0xFF37404F), height: 28),
                  _infoRow('Backend', 'Node.js · Express · PostgreSQL'),
                  const Divider(color: Color(0xFF37404F), height: 28),
                  _infoRow('Frontend', 'Flutter Web / Desktop'),
                ])),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            color: Color(0xFF78909C),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2));
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: child,
    );
  }

  Widget _dropdownRow(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    final safeValue = items.contains(value) ? value : items.first;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                isExpanded: true,
                dropdownColor: const Color(0xFF252A3A),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged, {
    String? valueLabel,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                valueLabel ?? value.toString(),
                style: const TextStyle(
                    color: Color(0xFF1E88E5),
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: const Color(0xFF1E88E5),
            inactiveTrackColor: const Color(0xFF37404F),
            thumbColor: const Color(0xFF1E88E5),
            overlayColor: const Color(0xFF1E88E5).withValues(alpha: 0.15),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(helperText,
                style: const TextStyle(color: Color(0xFF78909C), fontSize: 12)),
          ),
      ],
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged,
      {String? subtitle}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF78909C), fontSize: 12)),
                ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF1E88E5),
          activeTrackColor: const Color(0xFF1E88E5).withValues(alpha: 0.4),
          inactiveThumbColor: const Color(0xFF78909C),
          inactiveTrackColor: const Color(0xFF37404F),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(label,
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14)),
        ),
        Expanded(
          flex: 3,
          child: Text(value,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildAnomalyDetectionCard(SettingsProvider sp) {
    final mlStatus = sp.mlStatus;
    final activeModel = mlStatus?['active_model'];
    final hasModel = activeModel != null;

    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detection mode indicator
        Row(
          children: [
            Icon(
              hasModel ? Icons.auto_awesome : Icons.rule,
              color:
                  hasModel ? const Color(0xFF3CCB7F) : const Color(0xFFFFA726),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasModel
                    ? 'Rules Engine + K-Means Model Active'
                    : 'Rules Engine Only (No ML Model)',
                style: TextStyle(
                  color: hasModel
                      ? const Color(0xFF3CCB7F)
                      : const Color(0xFFFFA726),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const Divider(color: Color(0xFF37404F), height: 28),

        // Model status info
        if (hasModel) ...[
          _infoRow('Model ID', activeModel['model_id']?.toString() ?? 'N/A'),
          const SizedBox(height: 8),
          _infoRow('Last Trained', _formatDate(activeModel['training_date'])),
          const SizedBox(height: 8),
          _infoRow('Training Samples',
              activeModel['training_samples']?.toString() ?? '0'),
          const SizedBox(height: 8),
          _infoRow(
              'Silhouette Score',
              (activeModel['silhouette_score'] is num)
                  ? (activeModel['silhouette_score'] as num).toStringAsFixed(4)
                  : '0'),
          const SizedBox(height: 8),
          _infoRow('Clusters', activeModel['num_clusters']?.toString() ?? '0'),
        ] else ...[
          const Text(
            'No ML model is currently active. The system is detecting anomalies '
            'using the rules engine and statistical analysis only. '
            'Train a K-Means model to enable additional pattern detection.',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ],
        const Divider(color: Color(0xFF37404F), height: 28),

        // Training data info
        _infoRow('Available Samples',
            mlStatus?['available_training_samples']?.toString() ?? '0'),
        const SizedBox(height: 8),
        _infoRow('Minimum Required',
            mlStatus?['minimum_required_samples']?.toString() ?? '100'),
        const SizedBox(height: 8),
        _infoRow('Recent Detections (30d)',
            mlStatus?['recent_detections']?.toString() ?? '0'),
        const SizedBox(height: 8),
        _infoRow('False Positive Rate',
            mlStatus?['false_positive_rate']?.toString() ?? '0%'),
        const Divider(color: Color(0xFF37404F), height: 28),

        // Train Model button
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Train K-Means Model',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    sp.canTrain
                        ? 'Sufficient samples available for training'
                        : 'Need more custody records before training',
                    style:
                        const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: sp.isTraining || !sp.canTrain
                  ? null
                  : () async {
                      await sp.trainModel();
                      if (mounted && sp.trainingError == null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Model training completed'),
                          backgroundColor: Color(0xFF3CCB7F),
                        ));
                      }
                    },
              icon: sp.isTraining
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.model_training, size: 16),
              label: Text(sp.isTraining ? 'Training...' : 'Train Model'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                disabledBackgroundColor: const Color(0xFF37404F),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF78909C),
              ),
            ),
          ],
        ),

        // Training error display
        if (sp.trainingError != null) ...[
          const SizedBox(height: 8),
          Text(
            sp.trainingError!,
            style: const TextStyle(color: Color(0xFFE85C5C), fontSize: 12),
          ),
        ],
      ],
    ));
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Never';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.day}/${date.month}/${date.year} '
          '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.toString();
    }
  }

  Widget _resetButton(SettingsProvider sp) {
    return TextButton.icon(
      onPressed: () async {
        final confirmed = await DeleteConfirmationDialog.show(
          context,
          title: 'Reset Settings?',
          message:
              'You are about to restore all settings to their default values.',
          detail:
              'Any custom configuration will be lost. This cannot be undone.',
          confirmText: 'Reset',
        );
        if (confirmed == true) {
          await sp.resetToDefaults();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Settings reset to defaults'),
              backgroundColor: Color(0xFF3CCB7F),
            ));
          }
        }
      },
      icon: const Icon(Icons.restart_alt, size: 16, color: Color(0xFF78909C)),
      label: const Text('Reset',
          style: TextStyle(color: Color(0xFF78909C), fontSize: 13)),
    );
  }
}
