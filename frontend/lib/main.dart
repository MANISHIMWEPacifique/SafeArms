// SafeArms Frontend - Main Entry Point
// This is the starting point of the Flutter application

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/firearm_provider.dart';
import 'providers/custody_provider.dart';
import 'providers/anomaly_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/approval_provider.dart';
import 'providers/unit_provider.dart';
import 'providers/officer_provider.dart';
import 'providers/approvals_provider.dart';
import 'providers/user_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/ballistic_profile_provider.dart';
import 'providers/operations_provider.dart';
import 'screens/auth/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeArmsApp());
}

class SafeArmsApp extends StatelessWidget {
  const SafeArmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth is the only provider needed at login — created eagerly.
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // All other providers are lazy: created only when first accessed
        // after the user logs in and navigates to a screen that reads them.
        ChangeNotifierProvider.value(value: FirearmProvider()),
        ChangeNotifierProvider.value(value: CustodyProvider()),
        ChangeNotifierProvider.value(value: AnomalyProvider()),
        ChangeNotifierProvider.value(value: DashboardProvider()),
        ChangeNotifierProvider.value(value: ApprovalProvider()),
        ChangeNotifierProvider.value(value: UnitProvider()),
        ChangeNotifierProvider.value(value: OfficerProvider()),
        ChangeNotifierProvider.value(value: ApprovalsProvider()),
        ChangeNotifierProvider.value(value: UserProvider()),
        ChangeNotifierProvider.value(value: SettingsProvider()),
        ChangeNotifierProvider.value(value: BallisticProfileProvider()),
        ChangeNotifierProvider.value(value: OperationsProvider()),
      ],
      child: MaterialApp(
        title: 'SafeArms',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFF1A1F2E),
          fontFamily: 'Roboto',
          brightness: Brightness.dark,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
