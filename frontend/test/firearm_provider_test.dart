import 'package:flutter_test/flutter_test.dart';
import 'package:safearms_frontend/models/firearm_model.dart';
import 'package:safearms_frontend/providers/firearm_provider.dart';
import 'package:safearms_frontend/services/firearm_service.dart';

void main() {
  group('FirearmProvider registry consistency', () {
    test('loads 30 firearms with full-scope stats and a non-empty first page',
        () async {
      final service = _FakeFirearmService(_buildFirearms(30));
      final provider = FirearmProvider(firearmService: service);

      await provider.loadRegistry();

      expect(provider.stats['total'], 30);
      expect(provider.unfilteredCount, 30);
      expect(provider.filteredCount, 30);
      expect(provider.paginatedFirearms, hasLength(12));
      expect(provider.paginationSummary, 'Showing 1-12 of 30 firearms');
    });

    test('clamps current page when refreshed data has fewer pages', () async {
      final service = _FakeFirearmService(_buildFirearms(30));
      final provider = FirearmProvider(firearmService: service);

      await provider.loadRegistry();
      provider.setPage(3);
      expect(provider.currentPage, 3);

      service.firearms = _buildFirearms(13);
      await provider.loadRegistry();

      expect(provider.currentPage, 2);
      expect(provider.paginatedFirearms, hasLength(1));
      expect(provider.paginationSummary, 'Showing 13-13 of 13 firearms');
    });

    test('active filters can empty the list while stats remain full-scope',
        () async {
      final service = _FakeFirearmService(_buildFirearms(30));
      final provider = FirearmProvider(firearmService: service);

      await provider.loadRegistry();
      provider.setSearchQuery('serial-that-does-not-exist');

      expect(provider.stats['total'], 30);
      expect(provider.filteredCount, 0);
      expect(provider.isFilteredEmpty, isTrue);
      expect(provider.paginatedFirearms, isEmpty);
      expect(provider.paginationSummary, 'Showing 0 matching firearms');
    });

    test('successful delete removes firearm and refreshes stats', () async {
      final service = _FakeFirearmService(_buildFirearms(30));
      final provider = FirearmProvider(firearmService: service);

      await provider.loadRegistry();
      final success = await provider.deleteFirearm('FA-001');

      expect(success, isTrue);
      expect(provider.firearms.any((f) => f.firearmId == 'FA-001'), isFalse);
      expect(provider.unfilteredCount, 29);
      expect(provider.stats['total'], 29);
    });

    test('failed delete preserves firearms and stats', () async {
      final service = _FakeFirearmService(
        _buildFirearms(30),
        deleteError: 'Cannot delete firearm with operational history.',
      );
      final provider = FirearmProvider(firearmService: service);

      await provider.loadRegistry();
      final success = await provider.deleteFirearm('FA-001');

      expect(success, isFalse);
      expect(provider.firearms.any((f) => f.firearmId == 'FA-001'), isTrue);
      expect(provider.unfilteredCount, 30);
      expect(provider.stats['total'], 30);
      expect(provider.errorMessage, contains('operational history'));
    });
  });
}

class _FakeFirearmService extends FirearmService {
  _FakeFirearmService(this.firearms, {this.deleteError});

  List<FirearmModel> firearms;
  final String? deleteError;

  @override
  Future<List<FirearmModel>> getAllFirearms({
    String? status,
    String? type,
    String? unitId,
    String? manufacturer,
    int limit = FirearmService.registryFetchLimit,
    int offset = 0,
  }) async {
    final rows = unitId == null
        ? firearms
        : firearms.where((f) => f.assignedUnitId == unitId).toList();
    return rows.skip(offset).take(limit).toList();
  }

  @override
  Future<List<FirearmModel>> getUnitFirearms({
    required String unitId,
    String? status,
    String? type,
    int limit = FirearmService.registryFetchLimit,
    int offset = 0,
  }) async {
    return getAllFirearms(unitId: unitId, limit: limit, offset: offset);
  }

  @override
  Future<Map<String, dynamic>> getFirearmStats({String? unitId}) async {
    final scoped = unitId == null
        ? firearms
        : firearms.where((f) => f.assignedUnitId == unitId).toList();
    return {
      'total': scoped.length,
      'available': scoped.where((f) => f.currentStatus == 'available').length,
      'in_custody': scoped.where((f) => f.currentStatus == 'in_custody').length,
      'maintenance':
          scoped.where((f) => f.currentStatus == 'maintenance').length,
    };
  }

  @override
  Future<void> deleteFirearm(String firearmId) async {
    if (deleteError != null) {
      throw Exception(deleteError);
    }
    firearms = firearms.where((f) => f.firearmId != firearmId).toList();
  }
}

List<FirearmModel> _buildFirearms(int count) {
  return List.generate(count, (index) {
    final number = index + 1;
    final padded = number.toString().padLeft(3, '0');
    return FirearmModel(
      firearmId: 'FA-$padded',
      serialNumber: 'SERIAL-$padded',
      manufacturer: number.isEven ? 'Glock' : 'Beretta',
      model: 'Model $number',
      firearmType: number.isEven ? 'pistol' : 'rifle',
      caliber: '9mm',
      acquisitionDate: DateTime(2024, 1, 1),
      registrationLevel: 'hq',
      registeredBy: 'USR-001',
      assignedUnitId: number.isEven ? 'UNIT-HQ' : 'UNIT-NYA',
      currentStatus: number % 5 == 0 ? 'in_custody' : 'available',
      isActive: true,
    );
  });
}
