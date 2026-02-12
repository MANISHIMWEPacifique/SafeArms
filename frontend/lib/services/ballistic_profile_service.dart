// Ballistic Profile Service - API calls for forensic ballistic profiles
// SafeArms Frontend

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import './auth_service.dart';

class BallisticProfileService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get all ballistic profiles with filters
  Future<List<Map<String, dynamic>>> getAllProfiles({
    String? firearmType,
    String? status,
    String? searchQuery,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}/api/ballistic-profiles';

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

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception(
            'Failed to load ballistic profiles: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching ballistic profiles: $e');
    }
  }

  // Get profile by ID
  Future<Map<String, dynamic>> getProfileById(String profileId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/ballistic-profiles/$profileId'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  // Create new ballistic profile - HQ Commander only during firearm registration
  // Profiles are immutable after creation for forensic integrity
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
      final headers = await _getHeaders();
      final body = json.encode({
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
      });

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/ballistic-profiles'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create profile');
      }
    } catch (e) {
      throw Exception('Error creating profile: $e');
    }
  }

  // UPDATE REMOVED - Ballistic profiles are immutable after HQ registration
  // Profiles can only be created during firearm registration at HQ
  // This ensures forensic integrity for investigative search and matching

  // Get profile statistics
  Future<Map<String, dynamic>> getProfileStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/ballistic-profiles/stats'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load stats');
      }
    } catch (e) {
      throw Exception('Error fetching stats: $e');
    }
  }

  // Search ballistic profiles by characteristics for matching purposes
  // Read-only search for investigative support
  Future<List<Map<String, dynamic>>> forensicSearch({
    String? riflingPattern,
    int? landGrooveCount,
    String? twistDirection,
    String? caliber,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}/api/ballistic-profiles/forensic-search';

      List<String> queryParams = [];
      if (riflingPattern != null && riflingPattern.isNotEmpty) {
        queryParams.add('rifling_pattern=$riflingPattern');
      }
      if (landGrooveCount != null) {
        queryParams.add('land_groove_count=$landGrooveCount');
      }
      if (twistDirection != null && twistDirection.isNotEmpty) {
        queryParams.add('twist_direction=$twistDirection');
      }
      if (caliber != null && caliber.isNotEmpty) {
        queryParams.add('caliber=$caliber');
      }
      if (startDate != null) {
        queryParams.add('start_date=${startDate.toIso8601String()}');
      }
      if (endDate != null) {
        queryParams.add('end_date=${endDate.toIso8601String()}');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error in forensic search: $e');
    }
  }

  // Get custody history for a firearm
  Future<List<Map<String, dynamic>>> getFirearmCustodyHistory(
      String firearmId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.custody}?firearm_id=$firearmId'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load custody history');
      }
    } catch (e) {
      throw Exception('Error fetching custody history: $e');
    }
  }
}
