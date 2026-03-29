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
import 'dart:async';

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

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
      child: SessionTimeoutManager(
        child: MaterialApp(
          navigatorKey: _appNavigatorKey,
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
      ),
    );
  }
}

class SessionTimeoutManager extends StatefulWidget {
  final Widget child;
  const SessionTimeoutManager({super.key, required this.child});

  @override
  State<SessionTimeoutManager> createState() => _SessionTimeoutManagerState();
}

class _SessionTimeoutManagerState extends State<SessionTimeoutManager> {
  Timer? _authTimer;
  AuthProvider? _authProvider;
  SettingsProvider? _settingsProvider;
  int? _currentTimeoutMinutes;
  bool _hasRequestedAuthenticatedSettingsLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _authProvider = context.read<AuthProvider>();
      _settingsProvider = context.read<SettingsProvider>();

      _authProvider?.addListener(_handleProviderStateChanged);
      _settingsProvider?.addListener(_handleProviderStateChanged);
      _syncTimerWithAuthState();
    });
  }

  @override
  void dispose() {
    _authTimer?.cancel();
    _authProvider?.removeListener(_handleProviderStateChanged);
    _settingsProvider?.removeListener(_handleProviderStateChanged);
    super.dispose();
  }

  void _handleProviderStateChanged() {
    _syncTimerWithAuthState();
  }

  void _syncTimerWithAuthState() {
    final auth = _authProvider ?? context.read<AuthProvider>();
    final settings = _settingsProvider ?? context.read<SettingsProvider>();

    if (!auth.isAuthenticated) {
      _authTimer?.cancel();
      _authTimer = null;
      _currentTimeoutMinutes = null;
      _hasRequestedAuthenticatedSettingsLoad = false;
      return;
    }

    if (!_hasRequestedAuthenticatedSettingsLoad) {
      _hasRequestedAuthenticatedSettingsLoad = true;
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        final latestAuth = _authProvider ?? context.read<AuthProvider>();
        if (!latestAuth.isAuthenticated) return;
        unawaited(settings.loadSettings());
      });
    }

    final timeoutMinutes =
        settings.sessionTimeout > 0 ? settings.sessionTimeout : 20;

    if (_authTimer != null && _currentTimeoutMinutes == timeoutMinutes) {
      return;
    }

    _currentTimeoutMinutes = timeoutMinutes;
    _authTimer?.cancel();
    _authTimer = Timer(Duration(minutes: timeoutMinutes), _handleTimeout);
  }

  void _resetTimer() {
    _authTimer?.cancel();
    final auth = _authProvider ?? context.read<AuthProvider>();
    final settings = _settingsProvider ?? context.read<SettingsProvider>();

    if (auth.isAuthenticated) {
      final timeoutMinutes =
          settings.sessionTimeout > 0 ? settings.sessionTimeout : 20;
      _currentTimeoutMinutes = timeoutMinutes;
      _authTimer = Timer(Duration(minutes: timeoutMinutes), _handleTimeout);
    } else {
      _authTimer = null;
      _currentTimeoutMinutes = null;
    }
  }

  Future<void> _handleTimeout() async {
    final auth = _authProvider ?? context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      await auth.logout();

      _authTimer?.cancel();
      _authTimer = null;
      _currentTimeoutMinutes = null;

      if (!mounted) return;

      _appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(
            sessionExpiredMessage: 'Session expired. Please sign in again.',
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
