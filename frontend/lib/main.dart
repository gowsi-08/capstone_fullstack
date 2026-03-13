import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'map_screen.dart';
import 'app_state.dart';
import 'db_helper.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import 'digitized_map_view.dart';
import 'training_data_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.instance.initDB();

  // Load saved login state
  final appState = await AppState.loadSavedState();

  runApp(IndoorNavigationApp(appState: appState));
}

class IndoorNavigationApp extends StatelessWidget {
  final AppState appState;
  const IndoorNavigationApp({Key? key, required this.appState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        title: 'Indoor Navigation',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
        ),
        // If already logged in, go directly to MapScreen
        home: appState.isLoggedIn ? const MapScreen() : const LoginScreen(),
        routes: {
          '/home': (_) => const MapScreen(),
          '/admin_panel': (_) => const AdminScreen(),
          '/digitized': (_) => const DigitizedMapView(),
          '/training_data': (_) => const TrainingDataScreen(),
          '/login': (_) => const LoginScreen(),
        },
      ),
    );
  }
}
