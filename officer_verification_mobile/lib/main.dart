import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'screens/verification_flow_screen.dart';
import 'services/api_discovery_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();

  final discoveryService = ApiDiscoveryService();
  try {
    await discoveryService.refresh(trigger: DiscoveryRefreshTrigger.startup);
  } finally {
    discoveryService.dispose();
  }

  runApp(const OfficerVerificationApp());
}

class OfficerVerificationApp extends StatelessWidget {
  const OfficerVerificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeArms Officer Verification',
      theme: AppTheme.lightTheme(),
      home: const VerificationFlowScreen(),
    );
  }
}
