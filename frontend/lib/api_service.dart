import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:http/http.dart' as http;

class ApiService {
  // Determine baseUrl based on platform
  static const String _productionUrl = "https://capstone-server-yadf.onrender.com";
  static const String _localIp = "10.0.2.2"; // 10.0.2.2 = Emulator, 127.0.0.1 = Windows/Web

  static String get baseUrl {
    // Set this to true to use the Render production backend
    const bool useProduction = true; 

    if (useProduction) {
      return _productionUrl;
    }
    
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://$_localIp:5000'; 
    } else {
      return 'http://127.0.0.1:5000'; 
    }
  }

  // ==================
  // AUTH
  // ==================
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      print('🔐 AUTH REQUEST: $url');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim().toLowerCase(),
          'password': password.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        if (j['success'] == true) {
          return j['user'];
        }
      }
      print('❌ AUTH FAILED: ${resp.statusCode} - ${resp.body}');
    } catch (e) {
      print('❌ AUTH CONNECTION FAILED: $e');
    }
    return null;
  }

  // ==================
  // PREDICTION
  // ==================
  static Future<Map<String, String>?> predictLocation(List<Map<String, dynamic>> payload) async {
    try {
      final url = Uri.parse('$baseUrl/getlocation');
      print('🌐 API REQUEST: $url');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
      
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        if (j is List && j.isNotEmpty) {
          final data = j[0];
          print('🌐 API RESPONSE: ${resp.body}');
          return {
            'predicted': data['predicted']?.toString() ?? 'Unknown',
            'source': data['source']?.toString() ?? 'local',
          };
        }
      } else {
        print('❌ SERVER ERROR: ${resp.statusCode} - ${resp.body}');
      }
    } catch (e) {
      print('❌ CONNECTION FAILED: $e');
    }
    return null;
  }

  // ==================
  // MAP
  // ==================
  static Future<String?> getMapBase64(String floor) async {
    try {
      final url = Uri.parse('$baseUrl/admin/map_base64/$floor');
      print('Fetching map from: $url');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        return j['base64'];
      } else {
        print('Server error: ${resp.statusCode}');
        return null;
      }
    } catch (e) {
      print('Failed to load base64 map: $e');
      return null;
    }
  }

  // ==================
  // LOCATIONS
  // ==================
  static Future<List<dynamic>> getAllLocations() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/locations/all'));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (e) {
      print('Error fetching all locations: $e');
    }
    return [];
  }

  // ==================
  // TRAINING DATA
  // ==================
  static Future<Map<String, dynamic>?> submitTrainingData({
    required String location,
    required String landmark,
    required String floor,
    required List<Map<String, dynamic>> scans,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-data');
      print('📝 TRAINING DATA REQUEST: $url');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'location': location,
          'landmark': landmark,
          'floor': floor,
          'scans': scans,
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        print('📝 TRAINING DATA RESPONSE: ${resp.body}');
        return j;
      } else {
        print('❌ TRAINING DATA ERROR: ${resp.statusCode} - ${resp.body}');
      }
    } catch (e) {
      print('❌ TRAINING DATA CONNECTION FAILED: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getTrainingStats() async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-stats');
      print('📊 Fetching stats from: $url');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      print('📊 Stats response: ${resp.statusCode} - ${resp.body}');
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (e) {
      print('❌ Error fetching training stats: $e');
    }
    return null;
  }

  static Future<bool> triggerRetrain() async {
    try {
      final url = Uri.parse('$baseUrl/admin/retrain');
      final resp = await http.post(url).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      print('Error triggering retrain: $e');
      return false;
    }
  }

  // ==================
  // TRAINING RECORDS CRUD (MongoDB)
  // ==================
  
  /// Get paginated training records with optional filters
  static Future<Map<String, dynamic>> getTrainingRecordsPaginated({
    int page = 1,
    int limit = 50,
    int? floor,
    String? location,
    String? source,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (floor != null) 'floor': floor.toString(),
        if (location != null && location.isNotEmpty) 'location': location,
        if (source != null && source.isNotEmpty) 'source': source,
      };
      final url = Uri.parse('$baseUrl/admin/training-records').replace(queryParameters: queryParams);
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (e) {
      print('Error fetching training records: $e');
    }
    return {'records': [], 'total': 0, 'page': page, 'limit': limit, 'pages': 0};
  }

  /// Get training records grouped by location
  static Future<Map<String, dynamic>> getTrainingRecordsGrouped({int? floor}) async {
    try {
      final queryParams = {
        if (floor != null) 'floor': floor.toString(),
      };
      final url = Uri.parse('$baseUrl/admin/training-records/grouped').replace(queryParameters: queryParams);
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (e) {
      print('Error fetching grouped records: $e');
    }
    return {};
  }

  /// Get distinct locations list with counts
  static Future<List<dynamic>> getTrainingLocations() async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-records/locations');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as List<dynamic>;
      }
    } catch (e) {
      print('Error fetching locations: $e');
    }
    return [];
  }

  /// Add single training record
  static Future<bool> addTrainingRecord(Map<String, dynamic> record) async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-records');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(record),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 201;
    } catch (e) {
      print('Error adding training record: $e');
      return false;
    }
  }

  /// Bulk insert training records
  static Future<bool> addTrainingRecordsBulk(List<Map<String, dynamic>> records) async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-records/bulk');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'records': records}),
      ).timeout(const Duration(seconds: 15));
      return resp.statusCode == 201;
    } catch (e) {
      print('Error bulk adding records: $e');
      return false;
    }
  }

  /// Update single training record
  static Future<bool> updateTrainingRecord(String id, Map<String, dynamic> updates) async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-records/$id');
      final resp = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      print('Error updating training record: $e');
      return false;
    }
  }

  /// Bulk update training records
  static Future<bool> updateTrainingRecordsBulk(List<String> ids, Map<String, dynamic> updates) async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-records/bulk');
      final resp = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ids': ids, 'updates': updates}),
      ).timeout(const Duration(seconds: 15));
      return resp.statusCode == 200;
    } catch (e) {
      print('Error bulk updating records: $e');
      return false;
    }
  }

  /// Delete single training record
  static Future<bool> deleteTrainingRecord(String id) async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-records/$id');
      final resp = await http.delete(url).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      print('Error deleting training record: $e');
      return false;
    }
  }

  /// Bulk delete training records
  static Future<bool> deleteTrainingRecordsBulk(List<String> ids) async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-records/bulk');
      final resp = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ids': ids}),
      ).timeout(const Duration(seconds: 15));
      return resp.statusCode == 200;
    } catch (e) {
      print('Error bulk deleting records: $e');
      return false;
    }
  }

  /// Delete all records for a location+floor group
  static Future<bool> deleteTrainingRecordsByGroup(String location, int floor) async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-records/group/$location').replace(
        queryParameters: {'floor': floor.toString()},
      );
      final resp = await http.delete(url).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      print('Error deleting group: $e');
      return false;
    }
  }

  /// Merge multiple locations into one
  static Future<bool> mergeTrainingLocations({
    required List<String> sourceLocations,
    required String targetLocation,
    required int floor,
    bool deleteSources = true,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-records/merge');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source_locations': sourceLocations,
          'target_location': targetLocation,
          'floor': floor,
          'delete_sources': deleteSources,
        }),
      ).timeout(const Duration(seconds: 15));
      return resp.statusCode == 200;
    } catch (e) {
      print('Error merging locations: $e');
      return false;
    }
  }

  /// Export training records as CSV (returns bytes)
  static Future<Uint8List?> exportTrainingRecords({int? floor, String? source}) async {
    try {
      final queryParams = {
        if (floor != null) 'floor': floor.toString(),
        if (source != null && source.isNotEmpty) 'source': source,
      };
      final url = Uri.parse('$baseUrl/admin/training-records/export').replace(queryParameters: queryParams);
      final resp = await http.get(url).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        return resp.bodyBytes;
      }
    } catch (e) {
      print('Error exporting records: $e');
    }
    return null;
  }
}
