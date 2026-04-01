import 'package:flutter/material.dart';

import 'screens/verification_flow_screen.dart';
import 'theme/app_theme.dart';

void main() {
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
