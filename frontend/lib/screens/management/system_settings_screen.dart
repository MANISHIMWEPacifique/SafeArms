// System Settings Screen
// Configure system settings and preferences

import 'package:flutter/material.dart';
import '../settings/system_settings_screen.dart' as settings;

/// Redirects to the main [settings.SystemSettingsScreen].
/// Kept for navigation compatibility.
class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const settings.SystemSettingsScreen();
  }
}
