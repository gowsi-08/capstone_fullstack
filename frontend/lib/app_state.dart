import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  // Using pixel offsets for now; later you can switch to fractional coordinates or transform them based on image scaling
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

  String get selectedDestination => _selectedDestination;
  String get predictedRoom => _predictedRoom;

  void setSelectedDestination(String dest) {
    _selectedDestination = dest;
    notifyListeners();
  }

  void setPredictedRoom(String room) {
    _predictedRoom = room;
    notifyListeners();
  }
}
