import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

import 'app_state.dart';
import 'search_widget.dart';
import 'api_service.dart';

class HomePage extends StatelessWidget {
  static const routeName = '/home';
  const HomePage({Key? key}) : super(key: key);

  Future<void> _onFabPressed(BuildContext context) async {
    // Request permission and scan
    var status = await Permission.location.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission required!')),
      );
      return;
    }
    await WiFiScan.instance.startScan();
    final List<WiFiAccessPoint>? list = await WiFiScan.instance.getScannedResults();
    if (list == null || list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No WiFi networks found!')),
      );
      return;
    }

    // Build payload for Flask
    final payload = list.map((ap) => {
      "BSSID": ap.bssid ?? "",
      "Signal Strength dBm": ap.level,
    }).toList();

    // Send to Flask and get location
    final predictedLocation = await ApiService.predictLocation(payload);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(predictedLocation == null
        ? 'Location not detected'
        : 'You are at: $predictedLocation')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Indoor Navigation'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Admin',
            onPressed: () {
              Navigator.pushNamed(context, '/admin');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onFabPressed(context),
        child: const Icon(Icons.my_location),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: SearchWidget(),
            ),

            // Map area - fill remaining space
            Expanded(
              child: Center(
                child: LayoutBuilder(builder: (context, constraints) {
                  // Map displayed centered and scaled to fit
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/map.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.grey[300]),
                        ),
                      ),

                      // If a destination selected show a simple marker and label
                      if (appState.selectedDestination.isNotEmpty &&
                          appState.roomPositions.containsKey(appState.selectedDestination))
                        Builder(builder: (context) {
                          final pos = appState.roomPositions[appState.selectedDestination]!;
                          // Map used as image with original pixel coordinates; we will place marker based on image size
                          // For easy/simple behavior, use Fractional positioning if positions are stored as fractions (but here we used offsets).
                          // We'll place by absolute offset — if map image scales, offsets must be adapted later.
                          return Positioned(
                            left: pos.dx,
                            top: pos.dy,
                            child: Column(
                              children: [
                                const Icon(Icons.flag, color: Colors.orange, size: 32),
                                const SizedBox(height: 2),
                                Container(
                                  color: Colors.white70,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(appState.selectedDestination),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  );
                }),
              ),
            ),

            // Simple bottom info area
            Container(
              width: double.infinity,
              color: Colors.grey[100],
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Text(
                'Predicted Location: ${appState.predictedRoom}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
