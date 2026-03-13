import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  // Using pixel offsets for now
  final Map<String, Offset> roomPositions = {
    'Network LAB': const Offset(80, 200),
    'Principal Room': const Offset(240, 60),
    'Boys restroom': const Offset(90, 40),
    'Guest Room': const Offset(360, 40),
    'Library': const Offset(140, 350),
    'Cafeteria': const Offset(280, 320),
  };

  String _selectedDestination = '';
  String _predictedRoom = 'Unknown';
  String _userType = 'Guest';
  bool _isAdmin = false;
  bool _isLoggedIn = false;

  String get selectedDestination => _selectedDestination;
  String get predictedRoom => _predictedRoom;
  String get userType => _userType;
  bool get isAdmin => _isAdmin;
  bool get isLoggedIn => _isLoggedIn;

  void setSelectedDestination(String dest) {
    _selectedDestination = dest;
    notifyListeners();
  }

  void setPredictedRoom(String room) {
    _predictedRoom = room;
    notifyListeners();
  }

  void setUser(String type, bool admin) {
    _userType = type;
    _isAdmin = admin;
    _isLoggedIn = true;
    notifyListeners();
    _saveLoginState();
  }

  Future<void> logout() async {
    _userType = 'Guest';
    _isAdmin = false;
    _isLoggedIn = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('userType');
    await prefs.remove('isAdmin');
  }

  Future<void> _saveLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userType', _userType);
    await prefs.setBool('isAdmin', _isAdmin);
  }

  /// Returns true if a saved session was restored
  static Future<AppState> loadSavedState() async {
    final appState = AppState();
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (loggedIn) {
      appState._isLoggedIn = true;
      appState._userType = prefs.getString('userType') ?? 'Guest';
      appState._isAdmin = prefs.getBool('isAdmin') ?? false;
    }
    return appState;
  }
}
