import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:http/http.dart' as http;

class ApiService {
  // Determine baseUrl based on platform
  // CHANGE THIS TO YOUR COMPUTER'S IP (e.g. 192.168.1.5) IF USING A PHYSICAL DEVICE
  static const String _serverIp = "10.0.2.2"; // 10.0.2.2 = Emulator, 127.0.0.1 = Windows/Web

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
  static Future<String?> getMapBase64(String floor) async {
    try {
      final url = Uri.parse('$baseUrl/admin/map_base64/$floor');
      print('Fetching map from: $url');
      final resp = await http.get(url).timeout(const Duration(seconds: 10)); // 10s timeout
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        return j['base64'];
      } else {
        print('Server error: ${resp.statusCode}');
        return null;
      }
    } catch (e) {
      print('Failed to load base64 map: $e');
      // Rethrow so UI can show it, or handle here?
      // Let's print it to console which shows in "flutter run" output
      return null;
    }
  }
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
}
