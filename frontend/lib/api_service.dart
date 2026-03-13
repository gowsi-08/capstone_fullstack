import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:http/http.dart' as http;

class ApiService {
  // Determine baseUrl based on platform
  static const String _productionUrl = "https://capstone-server-yadf.onrender.com";
  static const String _localIp = "10.0.2.2"; // 10.0.2.2 = Emulator, 127.0.0.1 = Windows/Web

  static String get baseUrl {
    // Set this to true to use the Render production backend
    const bool useProduction = false; 

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
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (e) {
      print('Error fetching training stats: $e');
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
  // TRAINING LOCATIONS (unique from MongoDB)
  // ==================
  static Future<List<Map<String, dynamic>>> getTrainingLocations() async {
    try {
      final url = Uri.parse('$baseUrl/admin/training-locations');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('Error fetching training locations: $e');
    }
    return [];
  }

  // ==================
  // ADD SINGLE MAP LOCATION
  // ==================
  static Future<bool> addMapLocation({
    required String name,
    required String floor,
    required double x,
    required double y,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/admin/location/add');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'floor': floor, 'x': x, 'y': y}),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      print('Error adding map location: $e');
      return false;
    }
  }
}
