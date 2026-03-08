// Ballistic Profile Service - API calls for forensic ballistic profiles
// SafeArms Frontend

import '../config/api_config.dart';
import 'api_client.dart';

class BallisticProfileService {
  // Get all ballistic profiles with filters
  Future<List<Map<String, dynamic>>> getAllProfiles({
    String? firearmType,
    String? status,
    String? searchQuery,
  }) async {
    try {
      List<String> queryParams = [];
      if (firearmType != null &&
          firearmType.isNotEmpty &&
          firearmType != 'all') {
        queryParams.add('firearm_type=$firearmType');
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams.add('status=$status');
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams.add('search=$searchQuery');
      }

      var url = ApiConfig.ballisticUrl;
      if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';

      final data = await ApiClient.get(url);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching ballistic profiles: $e');
    }
  }

  // Get profile by ID
  Future<Map<String, dynamic>> getProfileById(String profileId) async {
    try {
      final data = await ApiClient.get('${ApiConfig.ballisticUrl}/$profileId');
      return data['data'];
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  // Create new ballistic profile
  Future<Map<String, dynamic>> createProfile({
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
    try {
      final data = await ApiClient.post(
        ApiConfig.ballisticUrl,
        body: {
          'firearm_id': firearmId,
          'test_date': testDate.toIso8601String(),
          'test_location': testLocation,
          'rifling_characteristics': riflingCharacteristics,
          'firing_pin_impression': firingPinImpression,
          'ejector_marks': ejectorMarks,
          'extractor_marks': extractorMarks,
          'chamber_marks': chamberMarks,
          'test_conducted_by': testConductedBy,
          'forensic_lab': forensicLab,
          'test_ammunition': testAmmunition,
          'notes': notes,
        },
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error creating profile: $e');
    }
  }

  // Get profile statistics
  Future<Map<String, dynamic>> getProfileStats() async {
    try {
      final data = await ApiClient.get('${ApiConfig.ballisticUrl}/stats');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching stats: $e');
    }
  }

  // Search ballistic profiles by crime scene evidence
  Future<Map<String, dynamic>> forensicSearch({
    String? firingPin,
    String? caliber,
    String? rifling,
    String? chamberFeed,
    String? breechFace,
    String? generalSearch,
    String? incidentDate,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      List<String> queryParams = [];
      if (firingPin != null && firingPin.isNotEmpty) {
        queryParams.add('firing_pin=${Uri.encodeComponent(firingPin)}');
      }
      if (caliber != null && caliber.isNotEmpty) {
        queryParams.add('caliber=${Uri.encodeComponent(caliber)}');
      }
      if (rifling != null && rifling.isNotEmpty) {
        queryParams.add('rifling=${Uri.encodeComponent(rifling)}');
      }
      if (chamberFeed != null && chamberFeed.isNotEmpty) {
        queryParams.add('chamber_feed=${Uri.encodeComponent(chamberFeed)}');
      }
      if (breechFace != null && breechFace.isNotEmpty) {
        queryParams.add('breech_face=${Uri.encodeComponent(breechFace)}');
      }
      if (generalSearch != null && generalSearch.isNotEmpty) {
        queryParams.add('search=${Uri.encodeComponent(generalSearch)}');
      }
      if (incidentDate != null && incidentDate.isNotEmpty) {
        queryParams.add('incident_date=${Uri.encodeComponent(incidentDate)}');
      }
      queryParams.add('page=$page');
      queryParams.add('limit=$limit');

      final url =
          '${ApiConfig.ballisticUrl}/forensic-search?${queryParams.join('&')}';
      final data = await ApiClient.get(url);

      return {
        'data': List<Map<String, dynamic>>.from(data['data'] ?? []),
        'total': data['total'] ?? 0,
        'page': data['page'] ?? 1,
        'pageSize': data['pageSize'] ?? limit,
        'totalPages': data['totalPages'] ?? 1,
      };
    } catch (e) {
      throw Exception('Error in forensic search: $e');
    }
  }

  // Get custody history for a firearm
  Future<List<Map<String, dynamic>>> getFirearmCustodyHistory(
      String firearmId) async {
    try {
      final data =
          await ApiClient.get('${ApiConfig.custody}?firearm_id=$firearmId');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching custody history: $e');
    }
  }
}
