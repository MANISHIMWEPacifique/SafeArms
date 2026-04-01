import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'screens/verification_flow_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();
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
