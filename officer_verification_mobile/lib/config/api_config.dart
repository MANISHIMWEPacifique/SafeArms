import 'package:shared_preferences/shared_preferences.dart';

enum ApiBaseUrlSource { manual, discovered, lastKnownGood, buildDefault }

class ResolvedApiBaseUrl {
  const ResolvedApiBaseUrl({required this.baseUrl, required this.source});

  final String baseUrl;
  final ApiBaseUrlSource source;

  String get sourceLabel {
    switch (source) {
      case ApiBaseUrlSource.manual:
        return 'Manual';
      case ApiBaseUrlSource.discovered:
        return 'Discovered';
      case ApiBaseUrlSource.lastKnownGood:
        return 'Last known good';
      case ApiBaseUrlSource.buildDefault:
        return 'Build default';
    }
  }
}

class ApiConfig {
  static const String _defaultBaseUrl = 'http://10.0.2.2:5000/api';
  static const String _prefLegacyBaseUrl = 'safearms_api_base_url';
  static const String _prefManualBaseUrl = 'safearms_manual_api_base_url';
  static const String _prefManualBaseUrlUpdatedAt =
      'safearms_manual_api_base_url_updated_at';
  static const String _prefDiscoveredBaseUrl =
      'safearms_discovered_api_base_url';
  static const String _prefDiscoveredBackupBaseUrl =
      'safearms_discovered_backup_api_base_url';
  static const String _prefDiscoveredVersion = 'safearms_discovered_version';
  static const String _prefDiscoveredUpdatedAt =
      'safearms_discovered_updated_at';
  static const String _prefDiscoveredNotes = 'safearms_discovered_notes';
  static const String _prefDiscoveryLastSyncAt =
      'safearms_discovery_last_sync_at';
  static const String _prefDiscoveryLastError = 'safearms_discovery_last_error';
  static const String _prefLastKnownGoodBaseUrl =
      'safearms_last_known_good_api_base_url';
  static const String _prefLastKnownGoodUpdatedAt =
      'safearms_last_known_good_updated_at';
  static const String _prefOfficerId = 'safearms_officer_id';
  static const String _prefDeviceKey = 'safearms_device_key';
  static const String _prefDeviceToken = 'safearms_device_token';

  static const String baseUrl = String.fromEnvironment(
    'SAFEARMS_API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const String discoveryUrl = String.fromEnvironment(
    'SAFEARMS_DISCOVERY_URL',
    defaultValue: '',
  );

  static const bool useMockFlow = bool.fromEnvironment(
    'SAFEARMS_USE_MOCK_FLOW',
    defaultValue: false,
  );

  static const String officerId = String.fromEnvironment(
    'SAFEARMS_OFFICER_ID',
    defaultValue: '',
  );

  static const String deviceKey = String.fromEnvironment(
    'SAFEARMS_DEVICE_KEY',
    defaultValue: '',
  );

  static const String deviceToken = String.fromEnvironment(
    'SAFEARMS_DEVICE_TOKEN',
    defaultValue: '',
  );

  static String _manualBaseUrl = '';
  static String _manualBaseUrlUpdatedAt = '';
  static String _discoveredBaseUrl = '';
  static String _discoveredBackupBaseUrl = '';
  static String _discoveredVersion = '';
  static String _discoveredUpdatedAt = '';
  static String _discoveredNotes = '';
  static String _discoveryLastSyncAt = '';
  static String _discoveryLastError = '';
  static String _lastKnownGoodBaseUrl = '';
  static String _lastKnownGoodUpdatedAt = '';
  static String _runtimeOfficerId = '';
  static String _runtimeDeviceKey = '';
  static String _runtimeDeviceToken = '';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    _manualBaseUrl = _normalizeStoredBaseUrl(
      prefs.getString(_prefManualBaseUrl) ?? '',
    );
    _manualBaseUrlUpdatedAt =
        (prefs.getString(_prefManualBaseUrlUpdatedAt) ?? '').trim();

    _discoveredBaseUrl = _normalizeStoredBaseUrl(
      prefs.getString(_prefDiscoveredBaseUrl) ?? '',
    );
    _discoveredBackupBaseUrl = _normalizeStoredBaseUrl(
      prefs.getString(_prefDiscoveredBackupBaseUrl) ?? '',
    );
    _discoveredVersion = (prefs.getString(_prefDiscoveredVersion) ?? '').trim();
    _discoveredUpdatedAt = (prefs.getString(_prefDiscoveredUpdatedAt) ?? '')
        .trim();
    _discoveredNotes = (prefs.getString(_prefDiscoveredNotes) ?? '').trim();
    _discoveryLastSyncAt = (prefs.getString(_prefDiscoveryLastSyncAt) ?? '')
        .trim();
    _discoveryLastError = (prefs.getString(_prefDiscoveryLastError) ?? '')
        .trim();

    _lastKnownGoodBaseUrl = _normalizeStoredBaseUrl(
      prefs.getString(_prefLastKnownGoodBaseUrl) ?? '',
    );
    _lastKnownGoodUpdatedAt =
        (prefs.getString(_prefLastKnownGoodUpdatedAt) ?? '').trim();

    _runtimeOfficerId = (prefs.getString(_prefOfficerId) ?? '').trim();
    _runtimeDeviceKey = (prefs.getString(_prefDeviceKey) ?? '').trim();
    _runtimeDeviceToken = (prefs.getString(_prefDeviceToken) ?? '').trim();

    await _migrateLegacyBaseUrl(prefs);
  }

  static Future<void> saveRuntimeConfig({
    required String baseUrl,
    required String officerId,
    required String deviceKey,
    required String deviceToken,
  }) async {
    final normalizedBase = normalizeBaseUrlInput(baseUrl);
    if (!isValidHttpUrl(normalizedBase)) {
      throw const FormatException(
        'API Base URL must be a valid absolute URL using http:// or https://.',
      );
    }

    final normalizedOfficerId = officerId.trim();
    final normalizedDeviceKey = deviceKey.trim();
    final normalizedDeviceToken = deviceToken.trim();
    final manualUpdatedAt = _nowIsoString();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefManualBaseUrl, normalizedBase);
    await prefs.setString(_prefManualBaseUrlUpdatedAt, manualUpdatedAt);
    await prefs.setString(_prefOfficerId, normalizedOfficerId);
    await prefs.setString(_prefDeviceKey, normalizedDeviceKey);
    await prefs.setString(_prefDeviceToken, normalizedDeviceToken);

    _manualBaseUrl = normalizedBase;
    _manualBaseUrlUpdatedAt = manualUpdatedAt;
    _runtimeOfficerId = normalizedOfficerId;
    _runtimeDeviceKey = normalizedDeviceKey;
    _runtimeDeviceToken = normalizedDeviceToken;
  }

  static Future<bool> saveDiscoveredConfig({
    required String baseUrl,
    required String version,
    required String updatedAt,
    String? backupBaseUrl,
    String? notes,
  }) async {
    final normalizedBaseUrl = normalizeBaseUrlInput(baseUrl);
    if (!isValidHttpUrl(normalizedBaseUrl)) {
      throw const FormatException('Discovery api_base_url is invalid.');
    }

    final normalizedUpdatedAt = _normalizeTimestamp(updatedAt);
    if (normalizedUpdatedAt.isEmpty) {
      throw const FormatException(
        'Discovery updated_at must be a valid ISO timestamp.',
      );
    }

    final normalizedBackupBaseUrl = normalizeBaseUrlInput(backupBaseUrl ?? '');
    if (normalizedBackupBaseUrl.isNotEmpty &&
        !isValidHttpUrl(normalizedBackupBaseUrl)) {
      throw const FormatException('Discovery backup_api_base_url is invalid.');
    }

    final previousBaseUrl = resolvedBaseUrl.baseUrl;
    final now = _nowIsoString();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDiscoveredBaseUrl, normalizedBaseUrl);
    await prefs.setString(_prefDiscoveredVersion, version.trim());
    await prefs.setString(_prefDiscoveredUpdatedAt, normalizedUpdatedAt);
    await prefs.setString(
      _prefDiscoveredBackupBaseUrl,
      normalizedBackupBaseUrl,
    );
    await prefs.setString(_prefDiscoveredNotes, (notes ?? '').trim());
    await prefs.setString(_prefDiscoveryLastSyncAt, now);
    await prefs.setString(_prefDiscoveryLastError, '');

    _discoveredBaseUrl = normalizedBaseUrl;
    _discoveredVersion = version.trim();
    _discoveredUpdatedAt = normalizedUpdatedAt;
    _discoveredBackupBaseUrl = normalizedBackupBaseUrl;
    _discoveredNotes = (notes ?? '').trim();
    _discoveryLastSyncAt = now;
    _discoveryLastError = '';

    return previousBaseUrl != resolvedBaseUrl.baseUrl;
  }

  static Future<void> recordDiscoveryFailure(String message) async {
    final now = _nowIsoString();
    final normalizedMessage = message.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDiscoveryLastSyncAt, now);
    await prefs.setString(_prefDiscoveryLastError, normalizedMessage);

    _discoveryLastSyncAt = now;
    _discoveryLastError = normalizedMessage;
  }

  static Future<void> markCurrentBaseUrlHealthy() async {
    final resolved = resolvedBaseUrl;
    final normalizedBase = normalizeBaseUrlInput(resolved.baseUrl);
    if (normalizedBase.isEmpty || !isValidHttpUrl(normalizedBase)) {
      return;
    }

    final now = _nowIsoString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLastKnownGoodBaseUrl, normalizedBase);
    await prefs.setString(_prefLastKnownGoodUpdatedAt, now);

    _lastKnownGoodBaseUrl = normalizedBase;
    _lastKnownGoodUpdatedAt = now;
  }

  static Future<void> clearRuntimeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefLegacyBaseUrl);
    await prefs.remove(_prefManualBaseUrl);
    await prefs.remove(_prefManualBaseUrlUpdatedAt);
    await prefs.remove(_prefDiscoveredBaseUrl);
    await prefs.remove(_prefDiscoveredBackupBaseUrl);
    await prefs.remove(_prefDiscoveredVersion);
    await prefs.remove(_prefDiscoveredUpdatedAt);
    await prefs.remove(_prefDiscoveredNotes);
    await prefs.remove(_prefDiscoveryLastSyncAt);
    await prefs.remove(_prefDiscoveryLastError);
    await prefs.remove(_prefLastKnownGoodBaseUrl);
    await prefs.remove(_prefLastKnownGoodUpdatedAt);
    await prefs.remove(_prefOfficerId);
    await prefs.remove(_prefDeviceKey);
    await prefs.remove(_prefDeviceToken);

    _manualBaseUrl = '';
    _manualBaseUrlUpdatedAt = '';
    _discoveredBaseUrl = '';
    _discoveredBackupBaseUrl = '';
    _discoveredVersion = '';
    _discoveredUpdatedAt = '';
    _discoveredNotes = '';
    _discoveryLastSyncAt = '';
    _discoveryLastError = '';
    _lastKnownGoodBaseUrl = '';
    _lastKnownGoodUpdatedAt = '';
    _runtimeOfficerId = '';
    _runtimeDeviceKey = '';
    _runtimeDeviceToken = '';
  }

  static Future<void> clearDeviceCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefOfficerId);
    await prefs.remove(_prefDeviceKey);
    await prefs.remove(_prefDeviceToken);

    _runtimeOfficerId = '';
    _runtimeDeviceKey = '';
    _runtimeDeviceToken = '';
  }

  static ResolvedApiBaseUrl get resolvedBaseUrl {
    final normalizedManual = _normalizeStoredBaseUrl(_manualBaseUrl);
    final normalizedDiscovered = _normalizeStoredBaseUrl(_discoveredBaseUrl);
    final normalizedLastKnownGood = _normalizeStoredBaseUrl(
      _lastKnownGoodBaseUrl,
    );
    final normalizedBuildDefault = _normalizeStoredBaseUrl(baseUrl).isNotEmpty
        ? _normalizeStoredBaseUrl(baseUrl)
        : _defaultBaseUrl;

    if (normalizedManual.isNotEmpty && normalizedDiscovered.isNotEmpty) {
      if (_isDiscoveredNewerThanManual()) {
        return ResolvedApiBaseUrl(
          baseUrl: normalizedDiscovered,
          source: ApiBaseUrlSource.discovered,
        );
      }

      return ResolvedApiBaseUrl(
        baseUrl: normalizedManual,
        source: ApiBaseUrlSource.manual,
      );
    }

    if (normalizedDiscovered.isNotEmpty) {
      return ResolvedApiBaseUrl(
        baseUrl: normalizedDiscovered,
        source: ApiBaseUrlSource.discovered,
      );
    }

    if (normalizedManual.isNotEmpty) {
      return ResolvedApiBaseUrl(
        baseUrl: normalizedManual,
        source: ApiBaseUrlSource.manual,
      );
    }

    if (normalizedLastKnownGood.isNotEmpty) {
      return ResolvedApiBaseUrl(
        baseUrl: normalizedLastKnownGood,
        source: ApiBaseUrlSource.lastKnownGood,
      );
    }

    return ResolvedApiBaseUrl(
      baseUrl: normalizedBuildDefault,
      source: ApiBaseUrlSource.buildDefault,
    );
  }

  static String get effectiveBaseUrl {
    return resolvedBaseUrl.baseUrl;
  }

  static String get effectiveOfficerId {
    if (_runtimeOfficerId.isNotEmpty) {
      return _runtimeOfficerId;
    }
    return officerId;
  }

  static String get effectiveDeviceKey {
    if (_runtimeDeviceKey.isNotEmpty) {
      return _runtimeDeviceKey;
    }
    return deviceKey;
  }

  static String get effectiveDeviceToken {
    if (_runtimeDeviceToken.isNotEmpty) {
      return _runtimeDeviceToken;
    }
    return deviceToken;
  }

  static String get normalizedBaseUrl {
    return normalizeBaseUrlInput(effectiveBaseUrl);
  }

  static String get manualBaseUrl => _manualBaseUrl;

  static String get discoveredBaseUrl => _discoveredBaseUrl;

  static String get discoveredBackupBaseUrl => _discoveredBackupBaseUrl;

  static String get discoveredVersion => _discoveredVersion;

  static String get discoveredUpdatedAt => _discoveredUpdatedAt;

  static String get discoveredNotes => _discoveredNotes;

  static String get discoveryLastSyncAt => _discoveryLastSyncAt;

  static String get discoveryLastError => _discoveryLastError;

  static String get lastKnownGoodBaseUrl => _lastKnownGoodBaseUrl;

  static String get lastKnownGoodUpdatedAt => _lastKnownGoodUpdatedAt;

  static String normalizeBaseUrlInput(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static bool isValidHttpUrl(String value) {
    final normalized = normalizeBaseUrlInput(value);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.isAbsolute || uri.host.trim().isEmpty) {
      return false;
    }

    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static Uri? healthUriForBaseUrl(String baseUrl) {
    final normalized = normalizeBaseUrlInput(baseUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.isAbsolute || uri.host.trim().isEmpty) {
      return null;
    }

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isNotEmpty && segments.last.toLowerCase() == 'api') {
      segments.removeLast();
    }

    final healthSegments = [...segments, 'health'];
    return uri.replace(
      path: '/${healthSegments.join('/')}',
      query: null,
      fragment: null,
    );
  }

  static bool get hasDeviceCredentials {
    return effectiveOfficerId.trim().isNotEmpty &&
        effectiveDeviceKey.trim().isNotEmpty &&
        effectiveDeviceToken.trim().isNotEmpty;
  }

  static Future<void> _migrateLegacyBaseUrl(SharedPreferences prefs) async {
    final legacyBaseUrl = _normalizeStoredBaseUrl(
      prefs.getString(_prefLegacyBaseUrl) ?? '',
    );

    if (_manualBaseUrl.isEmpty && legacyBaseUrl.isNotEmpty) {
      final migrationTimestamp = _nowIsoString();
      await prefs.setString(_prefManualBaseUrl, legacyBaseUrl);
      await prefs.setString(_prefManualBaseUrlUpdatedAt, migrationTimestamp);

      _manualBaseUrl = legacyBaseUrl;
      _manualBaseUrlUpdatedAt = migrationTimestamp;
    }

    await prefs.remove(_prefLegacyBaseUrl);
  }

  static String _normalizeStoredBaseUrl(String value) {
    final normalized = normalizeBaseUrlInput(value);
    if (normalized.isEmpty || !isValidHttpUrl(normalized)) {
      return '';
    }

    return normalized;
  }

  static bool _isDiscoveredNewerThanManual() {
    final discoveredTimestamp = DateTime.tryParse(_discoveredUpdatedAt);
    final manualTimestamp = DateTime.tryParse(_manualBaseUrlUpdatedAt);

    if (discoveredTimestamp == null) {
      return false;
    }

    if (manualTimestamp == null) {
      return true;
    }

    return discoveredTimestamp.isAfter(manualTimestamp);
  }

  static String _normalizeTimestamp(String value) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return '';
    }

    return parsed.toUtc().toIso8601String();
  }

  static String _nowIsoString() => DateTime.now().toUtc().toIso8601String();
}
