import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safearms_frontend/models/firearm_model.dart';
import 'package:safearms_frontend/models/user_model.dart';
import 'package:safearms_frontend/providers/auth_provider.dart';
import 'package:safearms_frontend/providers/firearm_provider.dart';
import 'package:safearms_frontend/providers/user_provider.dart';
import 'package:safearms_frontend/screens/management/firearms_registry_screen.dart';
import 'package:safearms_frontend/screens/management/user_management_screen.dart';
import 'package:safearms_frontend/widgets/responsive_dashboard_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setViewport(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('admin scaffold stays desktop at 950px', (tester) async {
    await setViewport(tester, const Size(950, 720));

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveDashboardScaffold(
          desktopBreakpoint: 900,
          sideNavigation: SizedBox(width: 220, child: Text('Sidebar Nav')),
          topNavigation: SizedBox(height: 64, child: Text('Top Nav')),
          mainContent: Text('Main Content'),
        ),
      ),
    );

    expect(find.text('Sidebar Nav'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('users screen uses table layout at 950px and cards at 850px',
      (tester) async {
    await _pumpUsersScreen(tester, const Size(950, 720));

    expect(find.text('Actions'), findsOneWidget);

    await _pumpUsersScreen(tester, const Size(850, 720));

    expect(find.text('Actions'), findsNothing);
    expect(find.text('Admin Test User'), findsOneWidget);
  });

  testWidgets('firearms screen uses list table at 950px and cards at 850px',
      (tester) async {
    await _pumpFirearmsScreen(tester, const Size(950, 720));

    expect(find.text('SERIAL / MODEL'), findsOneWidget);

    await _pumpFirearmsScreen(tester, const Size(850, 720));

    expect(find.text('SERIAL / MODEL'), findsNothing);
    expect(find.text('SA-TEST-001'), findsOneWidget);
  });
}

Future<void> _pumpUsersScreen(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;

  await tester.pumpWidget(
    ChangeNotifierProvider<UserProvider>.value(
      value: _FakeUserProvider(),
      child: const MaterialApp(
        home: Scaffold(body: UserManagementScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpFirearmsScreen(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuthProvider()),
        ChangeNotifierProvider<FirearmProvider>.value(
          value: _FakeFirearmProvider(),
        ),
      ],
      child: const MaterialApp(home: FirearmsRegistryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeUserProvider extends UserProvider {
  final List<UserModel> _testUsers = [
    UserModel(
      userId: 'user-1',
      username: 'admin.test',
      fullName: 'Admin Test User',
      email: 'admin.test@safearms.local',
      role: 'admin',
      unitId: 'HQ',
      isActive: true,
      mustChangePassword: false,
      unitConfirmed: true,
    ),
  ];

  @override
  List<UserModel> get users => _testUsers;

  @override
  List<UserModel> get paginatedUsers => _testUsers;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Map<String, dynamic> get stats => const {
        'total': 1,
        'active': 1,
        'inactive': 0,
        'admins': 1,
      };

  @override
  int get totalPages => 1;

  @override
  Future<void> loadUsers() async {}

  @override
  Future<void> loadStats() async {}
}

class _FakeAuthProvider extends AuthProvider {
  @override
  Map<String, dynamic>? get currentUser => const {
        'role': 'admin',
        'full_name': 'Admin Test User',
      };

  @override
  String? get userName => 'Admin Test User';
}

class _FakeFirearmProvider extends FirearmProvider {
  final List<FirearmModel> _testFirearms = [
    FirearmModel(
      firearmId: 'firearm-1',
      serialNumber: 'SA-TEST-001',
      manufacturer: 'Glock',
      model: '17',
      firearmType: 'pistol',
      caliber: '9mm',
      acquisitionDate: DateTime(2024, 1, 1),
      registrationLevel: 'hq',
      registeredBy: 'user-1',
      assignedUnitId: 'HQ',
      assignedUnitName: 'Headquarters',
      currentStatus: 'available',
      isActive: true,
    ),
  ];

  @override
  List<FirearmModel> get firearms => _testFirearms;

  @override
  List<FirearmModel> get filteredFirearms => _testFirearms;

  @override
  List<FirearmModel> get paginatedFirearms => _testFirearms;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Map<String, dynamic> get stats => const {
        'total': 1,
        'available': 1,
        'in_custody': 0,
        'maintenance': 0,
      };

  @override
  bool get isGridView => false;

  @override
  int get totalPages => 1;

  @override
  String get paginationSummary => 'Showing 1-1 of 1 firearms';

  @override
  Future<void> loadRegistry({String? unitId}) async {}

  @override
  void toggleViewMode() {}
}
