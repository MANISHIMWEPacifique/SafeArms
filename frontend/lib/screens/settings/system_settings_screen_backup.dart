import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../widgets/delete_confirmation_dialog.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen>
    with SingleTickerProviderStateMixin {
  // Colors mapped from CSS vars
  static const Color _bg = Color(0xFF0F1623);
  static const Color _mainBg = Color(0xFF1A2233);
  static const Color _panelSurface = Color(0xFF212D42);
  static const Color _panelAlt = Color(0xFF273047);
  static const Color _b1 = Color(0x12FFFFFF); // ~rgba(255,255,255,0.07)
  static const Color _b2 = Color(0x1EFFFFFF); // ~rgba(255,255,255,0.12)
  static const Color _textPrimary = Color(0xFFE8EDF5);
  static const Color _textSecondary = Color(0xFF8B97AA);
  static const Color _textMuted = Color(0xFF5A6478);

  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentBlueDim = Color(0x263B82F6); // ~0.15
  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _warningAmber = Color(0xFFF59E0B);
  static const Color _warningAmberDim = Color(0x1FF59E0B); // ~0.12
  static const Color _dangerRed = Color(0xFFEF4444);
  static const Color _dangerRedDim = Color(0x1FEF4444);
  static const Color _teal = Color(0xFF14B8A6);
  static const Color _tealDim = Color(0x1F14B8A6);

  AnimationController? _pulseController;

  bool _securityValuesInitialized = false;
  bool _isTraining = false;

  bool _otpDragging = false;
  bool _maxAttemptsDragging = false;
  bool _passwordDragging = false;
  bool _sessionDragging = false;

  double _otpValidityValue = 6;
  double _maxOtpAttemptsValue = 5;
  double _minPasswordLengthValue = 8;
  double _sessionTimeoutValue = 30;

  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
      lowerBound: 0.35,
      upperBound: 1,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SettingsProvider>();
      sp.loadSettings();
      sp.loadMLStatus();
    });
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  void _syncSecurityValues(SettingsProvider sp) {
    if (!_securityValuesInitialized) {
      _securityValuesInitialized = true;
      _otpValidityValue = sp.otpValidityMinutes.toDouble();
      _maxOtpAttemptsValue = sp.maxOtpAttempts.toDouble();
      _minPasswordLengthValue = sp.minPasswordLength.toDouble();
      _sessionTimeoutValue = sp.sessionTimeout.toDouble();
      return;
    }

    if (!_otpDragging) {
      _otpValidityValue = sp.otpValidityMinutes.toDouble();
    }
    if (!_maxAttemptsDragging) {
      _maxOtpAttemptsValue = sp.maxOtpAttempts.toDouble();
    }
    if (!_passwordDragging) {
      _minPasswordLengthValue = sp.minPasswordLength.toDouble();
    }
    if (!_sessionDragging) {
      _sessionTimeoutValue = sp.sessionTimeout.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    _syncSecurityValues(sp);

    if (sp.isLoading) {
      return const ColoredBox(
        color: _mainBg,
        child: Center(
          child: CircularProgressIndicator(color: _accentBlue),
        ),
      );
    }

    return ColoredBox(
      color: _mainBg,
      child: DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(sp),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildContentWrapper(_buildDisplayTab(sp), sp),
                  _buildContentWrapper(_buildSecurityTab(sp), sp),
                  _buildContentWrapper(_buildAnomalyTab(sp), sp),
                  _buildContentWrapper(_buildAboutTab(), sp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentWrapper(Widget child, SettingsProvider sp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              const SizedBox(height: 32),
              _buildSaveBar(sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(SettingsProvider sp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _b1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accentBlueDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.settings, size: 20, color: _accentBlue),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Settings',
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Preferences are saved automatically',
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => _handleReset(sp),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset to defaults'),
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
              backgroundColor: _panelSurface,
              side: const BorderSide(color: _b2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return _dangerRed;
                }
                return _textSecondary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return _dangerRedDim;
                }
                return _panelSurface;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return const BorderSide(color: Color(0x66EF4444));
                }
                return const BorderSide(color: _b2);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _b1)),
      ),
      child: const TabBar(
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicatorColor: _accentBlue,
        indicatorWeight: 2,
        labelColor: _accentBlue,
        unselectedLabelColor: _textSecondary,
        labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        unselectedLabelStyle:
            TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        indicatorPadding: EdgeInsets.zero,
        labelPadding: EdgeInsets.symmetric(horizontal: 18),
        tabs: [
          Tab(
            height: 48,
            child: Row(
              children: [
                Icon(Icons.display_settings_outlined, size: 18),
                SizedBox(width: 8),
                Text('Display'),
              ],
            ),
          ),
          Tab(
            height: 48,
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 18),
                SizedBox(width: 8),
                Text('Security'),
              ],
            ),
          ),
          Tab(
            height: 48,
            child: Row(
              children: [
                Icon(Icons.manage_search_outlined, size: 18),
                SizedBox(width: 8),
                Text('Anomaly Detection'),
              ],
            ),
          ),
          Tab(
            height: 48,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18),
                SizedBox(width: 8),
                Text('About'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(SettingsProvider sp) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _dirty ? 1.0 : 0.4,
      child: IgnorePointer(
        ignoring: !_dirty,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _dirty = false;
                    _securityValuesInitialized = false;
                  });
                  _showSnack('Changes discarded',
                      backgroundColor: _panelSurface,
                      borderColor: _successGreen);
                },
                style: TextButton.styleFrom(
                  foregroundColor: _textSecondary,
                  side: const BorderSide(color: _b2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  textStyle: const TextStyle(fontSize: 15),
                ),
                child: const Text('Discard changes'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  setState(() => _dirty = false);
                  _showSnack('Settings saved successfully',
                      backgroundColor: _panelSurface,
                      borderColor: _successGreen);
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _accentBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.normal),
                ),
                child: const Text('Save settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel({required Widget header, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _panelSurface,
        border: Border.all(color: _b1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ...children,
        ],
      ),
    );
  }

  Widget _buildPanelHeader({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _b1)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: _textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildDisplayTab(SettingsProvider sp) {
    return _buildPanel(
      header: _buildPanelHeader(
        icon: Icons.display_settings_outlined,
        iconColor: _accentBlue,
        iconBg: _accentBlueDim,
        title: 'Display preferences',
        subtitle: 'Control how data is presented across the system',
      ),
      children: [
        _buildSettingRow(
          label: 'Date format',
          description: 'Applied to all date fields across the app',
          trailing: _buildSelect(
            value: sp.dateFormat,
            options: const ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'],
            onChanged: (val) {
              sp.setDateFormat(val);
              _markDirty();
            },
          ),
        ),
        _buildSettingRow(
          label: 'Time format',
          description: 'Choose between 12-hour AM/PM or 24-hour clock',
          trailing: _buildSelect(
            value: sp.timeFormat,
            options: const ['24-hour', '12-hour'],
            onChanged: (val) {
              sp.setTimeFormat(val);
              _markDirty();
            },
          ),
        ),
        _buildSettingRow(
          label: 'Items per page',
          description: 'Number of records shown in tables and lists',
          isLast: true,
          trailing: _buildSelect(
            value: sp.itemsPerPage.toString(),
            options: const ['10', '25', '50', '100'],
            onChanged: (val) {
              sp.setItemsPerPage(int.parse(val));
              _markDirty();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTab(SettingsProvider sp) {
    return _buildPanel(
      header: _buildPanelHeader(
        icon: Icons.shield_outlined,
        iconColor: _warningAmber,
        iconBg: _warningAmberDim,
        title: 'Security controls',
        subtitle: 'Authentication, sessions and access policy',
      ),
      children: [
        _buildSettingRow(
          label: 'Require two-factor authentication',
          description: 'Email OTP verification on every login',
          trailing: Switch(
            value: sp.enforce2FA,
            activeThumbColor: Colors.white,
            activeTrackColor: _accentBlue,
            inactiveTrackColor: _panelAlt,
            inactiveThumbColor: _textSecondary,
            trackOutlineColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.transparent;
              }
              return _b2;
            }),
            onChanged: (val) {
              sp.setEnforce2FA(val);
              _markDirty();
            },
          ),
        ),
        _buildSliderRow(
          label: 'OTP validity',
          description: 'Time window for OTP codes to remain valid',
          value: _otpValidityValue,
          min: 2,
          max: 30,
          divisions: 28,
          unit: 'min',
          onChanged: (val) {
            setState(() {
              _otpDragging = true;
              _otpValidityValue = val;
              _dirty = true;
            });
          },
          onChangeEnd: (val) {
            _otpDragging = false;
            sp.setOtpValidityMinutes(val.round());
          },
        ),
        _buildSliderRow(
          label: 'Max OTP attempts',
          description: 'Account locked after this many failed attempts',
          value: _maxOtpAttemptsValue,
          min: 1,
          max: 10,
          divisions: 9,
          unit: '',
          onChanged: (val) {
            setState(() {
              _maxAttemptsDragging = true;
              _maxOtpAttemptsValue = val;
              _dirty = true;
            });
          },
          onChangeEnd: (val) {
            _maxAttemptsDragging = false;
            sp.setMaxOtpAttempts(val.round());
          },
        ),
        _buildSliderRow(
          label: 'Minimum password length',
          description: 'Enforced for all new and updated passwords',
          value: _minPasswordLengthValue,
          min: 6,
          max: 32,
          divisions: 26,
          unit: 'chars',
          onChanged: (val) {
            setState(() {
              _passwordDragging = true;
              _minPasswordLengthValue = val;
              _dirty = true;
            });
          },
          onChangeEnd: (val) {
            _passwordDragging = false;
            sp.setMinPasswordLength(val.round());
          },
        ),
        _buildSliderRow(
          label: 'Session timeout',
          description: 'Auto-logout after this period of inactivity',
          value: _sessionTimeoutValue,
          min: 5,
          max: 120,
          divisions: 23,
          unit: 'min',
          isLast: true,
          onChanged: (val) {
            setState(() {
              _sessionDragging = true;
              _sessionTimeoutValue = val;
              _dirty = true;
            });
          },
          onChangeEnd: (val) {
            _sessionDragging = false;
            final rounded = (val / 5).round() * 5;
            sp.setSessionTimeout(rounded);
          },
        ),
      ],
    );
  }

  Widget _buildAnomalyTab(SettingsProvider sp) {
    return _buildPanel(
      header: _buildPanelHeader(
        icon: Icons.hub_outlined,
        iconColor: _teal,
        iconBg: _tealDim,
        title: 'Anomaly detection engine',
        subtitle: 'Rules Engine + K-Means clustering model',
        trailing: _buildModelActiveBadge(),
      ),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _b1)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 400;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: compact ? 2 : 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: compact ? 2.0 : 1.8,
                children: const [
                  _MiniStatCard(label: 'MODEL ID', value: 'MDL-001'),
                  _MiniStatCard(
                      label: 'LAST TRAINED',
                      value: 'Jan 8, 2025',
                      valueSize: 15),
                  _MiniStatCard(label: 'TRAINING SAMPLES', value: '134'),
                  _MiniStatCard(label: 'SILHOUETTE SCORE', value: '0.68'),
                ],
              );
            },
          ),
        ),
        _buildKvTable([
          {'label': 'Clusters', 'value': '4'},
          {'label': 'Available samples', 'value': '182'},
          {'label': 'Minimum required', 'value': '100'},
          {'label': 'Recent detections (30d)', 'value': '4'},
          {
            'label': 'False positive rate',
            'value': '75.0%',
            'color': _warningAmber
          },
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Train K-Means model',
                      style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  SizedBox(height: 4),
                  Text('Sufficient samples available for training',
                      style: TextStyle(color: _textSecondary, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isTraining
                    ? null
                    : () async {
                        setState(() => _isTraining = true);
                        await sp.trainModel();
                        if (!mounted) {
                          return;
                        }
                        setState(() => _isTraining = false);

                        if (sp.trainingError == null) {
                          _showSnack('K-Means model trained successfully',
                              backgroundColor: _panelSurface);
                          return;
                        }

                        _showSnack(sp.trainingError!,
                            backgroundColor: _panelSurface,
                            borderColor: _dangerRed);
                      },
                icon: _isTraining
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow, size: 16),
                label: Text(_isTraining ? 'Training...' : 'Train model'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _panelAlt,
                  disabledForegroundColor: _textMuted,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'DM Sans'),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTab() {
    return _buildPanel(
      header: _buildPanelHeader(
        icon: Icons.info_outline,
        iconColor: _textSecondary,
        iconBg: const Color(0x0FFFFFFF), // rgba(255,255,255,0.06)
        title: 'About SafeArms',
        subtitle: 'Platform and environment information',
      ),
      children: [
        _buildKvTable([
          {'label': 'Platform', 'value': 'SafeArms v1.0.0'},
          {'label': 'Organization', 'value': 'Rwanda National Police'},
          {'label': 'Backend', 'value': 'Node.js · Express · PostgreSQL'},
          {'label': 'Frontend', 'value': 'Flutter Web / Desktop'},
        ], isLast: true),
      ],
    );
  }

  Widget _buildSettingRow(
      {required String label,
      required String description,
      required Widget trailing,
      bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: _b1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(description,
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSelect(
      {required String value,
      required List<String> options,
      required Function(String) onChanged}) {
    final safeValue = options.contains(value) ? value : options.first;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _panelAlt,
        border: Border.all(color: _b2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          dropdownColor: _panelAlt,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 16, color: _textPrimary),
          style: const TextStyle(color: _textPrimary, fontSize: 15),
          isDense: true,
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              onChanged(v);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String description,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
    bool isLast = false,
  }) {
    final roundedVal = value.round();
    final valStr = unit.isEmpty ? '$roundedVal' : '$roundedVal $unit';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: _b1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(description,
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 13)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentBlueDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  valStr,
                  style: const TextStyle(
                      color: _accentBlue,
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 20,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: _accentBlue,
                inactiveTrackColor: _panelAlt,
                thumbColor: _accentBlue,
                overlayColor: _accentBlue.withValues(alpha: 0.1),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackShape: _CustomTrackShape(),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelActiveBadge() {
    final pulseAnimation =
        _pulseController ?? const AlwaysStoppedAnimation<double>(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _tealDim,
        border: Border.all(color: const Color(0x4014B8A6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: pulseAnimation,
            child: const Icon(Icons.circle, size: 8, color: _teal),
          ),
          const SizedBox(width: 8),
          const Text(
            'Model active',
            style: TextStyle(
                color: _teal, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildKvTable(List<Map<String, dynamic>> rows, {bool isLast = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: _b1)),
      ),
      child: Column(
        children: rows.map((r) {
          final isRowLast = r == rows.last;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              border: isRowLast
                  ? null
                  : const Border(bottom: BorderSide(color: _b1)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: Text(
                    r['label'] as String,
                    style: const TextStyle(color: _textSecondary, fontSize: 15),
                  ),
                ),
                Expanded(
                  child: Text(
                    r['value'] as String,
                    style: TextStyle(
                      color: r['color'] as Color? ?? _textPrimary,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _handleReset(SettingsProvider sp) async {
    final confirmed = await DeleteConfirmationDialog.show(
      context,
      title: 'Reset Settings?',
      message: 'You are about to restore all settings to their default values.',
      detail: 'Any custom configuration will be lost. This cannot be undone.',
      confirmText: 'Reset',
    );

    if (confirmed != true) {
      return;
    }

    await sp.resetToDefaults();
    if (!mounted) return;
    _showSnack('Reset to default values', backgroundColor: _panelSurface);
  }

  void _showSnack(String message,
      {required Color backgroundColor, Color borderColor = _successGreen}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        content: Row(
          children: [
            Icon(Icons.check, size: 18, color: borderColor),
            const SizedBox(width: 10),
            Text(message,
                style: const TextStyle(color: _textPrimary, fontSize: 14)),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor),
        ),
        margin: const EdgeInsets.only(bottom: 20, right: 20, left: 20),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard(
      {required this.label, required this.value, this.valueSize = 20});

  final String label;
  final String value;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _SystemSettingsScreenState._panelAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: _SystemSettingsScreenState._textPrimary,
              fontSize: valueSize,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _SystemSettingsScreenState._textSecondary,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
  }
}
