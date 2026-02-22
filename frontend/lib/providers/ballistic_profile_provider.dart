// Ballistic Profile Provider - State management for forensic ballistic profiles
// SafeArms Frontend

import 'package:flutter/foundation.dart';
import '../services/ballistic_profile_service.dart';

class BallisticProfileProvider with ChangeNotifier {
  final BallisticProfileService _ballisticProfileService =
      BallisticProfileService();

  // State
  List<Map<String, dynamic>> _profiles = [];
  Map<String, dynamic>? _selectedProfile;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _stats = {};

  // Filters
  String _firearmTypeFilter = 'all';
  String _statusFilter = 'all';
  String _searchQuery = '';

  // Getters
  List<Map<String, dynamic>> get profiles => _profiles;
  Map<String, dynamic>? get selectedProfile => _selectedProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get stats => _stats;

  String get firearmTypeFilter => _firearmTypeFilter;
  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  // Computed getters
  List<Map<String, dynamic>> get filteredProfiles {
    var filtered = List<Map<String, dynamic>>.from(_profiles);

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((profile) {
        final query = _searchQuery.toLowerCase();
        final serialNumber =
            (profile['serial_number'] ?? '').toString().toLowerCase();
        final manufacturer =
            (profile['manufacturer'] ?? '').toString().toLowerCase();
        return serialNumber.contains(query) || manufacturer.contains(query);
      }).toList();
    }

    // Apply filters
    if (_firearmTypeFilter != 'all') {
      filtered = filtered
          .where((p) => p['firearm_type'] == _firearmTypeFilter)
          .toList();
    }

    if (_statusFilter != 'all') {
      filtered =
          filtered.where((p) => p['profile_status'] == _statusFilter).toList();
    }

    return filtered;
  }

  // Load all profiles
  Future<void> loadProfiles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profiles = await _ballisticProfileService.getAllProfiles(
        firearmType: _firearmTypeFilter != 'all' ? _firearmTypeFilter : null,
        status: _statusFilter != 'all' ? _statusFilter : null,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load profile statistics
  Future<void> loadStats() async {
    try {
      _stats = await _ballisticProfileService.getProfileStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  // Select profile
  Future<void> selectProfile(String profileId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedProfile =
          await _ballisticProfileService.getProfileById(profileId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelectedProfile() {
    _selectedProfile = null;
    notifyListeners();
  }

  // Create new profile
  Future<bool> createProfile({
    required String firearmId,
    required DateTime testDate,
    required String testLocation,
    String? riflingCharacteristics,
    String? firingPinImpression,
    String? ejectorMarks,
    String? extractorMarks,
    String? chamberMarks,
    String? testConductedBy,
    String? forensicLab,
    String? testAmmunition,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ballisticProfileService.createProfile(
        firearmId: firearmId,
        testDate: testDate,
        testLocation: testLocation,
        riflingCharacteristics: riflingCharacteristics,
        firingPinImpression: firingPinImpression,
        ejectorMarks: ejectorMarks,
        extractorMarks: extractorMarks,
        chamberMarks: chamberMarks,
        testConductedBy: testConductedBy,
        forensicLab: forensicLab,
        testAmmunition: testAmmunition,
        notes: notes,
      );

      _isLoading = false;
      notifyListeners();

      // Reload data
      await loadProfiles();
      await loadStats();

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // UPDATE REMOVED - Ballistic profiles are immutable after HQ registration
  // Profiles can only be created during firearm registration at HQ
  // This ensures forensic integrity for investigative search and matching

  // Forensic search by ballistic characteristics
  Future<List<Map<String, dynamic>>> forensicSearch({
    String? firingPin,
    String? caliber,
    String? rifling,
    String? chamberFeed,
    String? breechFace,
    String? serialNumber,
    String? generalSearch,
  }) async {
    try {
      return await _ballisticProfileService.forensicSearch(
        firingPin: firingPin,
        caliber: caliber,
        rifling: rifling,
        chamberFeed: chamberFeed,
        breechFace: breechFace,
        serialNumber: serialNumber,
        generalSearch: generalSearch,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Set filters
  void setFirearmTypeFilter(String type) {
    _firearmTypeFilter = type;
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _firearmTypeFilter = 'all';
    _statusFilter = 'all';
    _searchQuery = '';
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
