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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FirearmProvider()),
        ChangeNotifierProvider(create: (_) => CustodyProvider()),
        ChangeNotifierProvider(create: (_) => AnomalyProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ApprovalProvider()),
        ChangeNotifierProvider(create: (_) => UnitProvider()),
        ChangeNotifierProvider(create: (_) => OfficerProvider()),
        ChangeNotifierProvider(create: (_) => ApprovalsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => BallisticProfileProvider()),
        ChangeNotifierProvider(create: (_) => OperationsProvider()),
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
