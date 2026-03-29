import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'map_screen.dart';
import 'app_state.dart';
import 'db_helper.dart';
import 'admin_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin/floor_plan_screen.dart';
import 'admin/location_marking_screen.dart';
import 'admin/geolocation_mapping_screen.dart';
import 'admin/location_testing_screen.dart';
import 'admin/training_data_screen.dart' as admin_training;
import 'admin/model_retraining_screen.dart';
import 'admin/stats_dashboard_screen.dart';
import 'login_screen.dart';
import 'digitized_map_view.dart';
import 'training_data_screen.dart' as legacy_training;


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
        title: 'FindMyWay — Indoor Navigation',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        // If already logged in, go directly to MapScreen
        home: appState.isLoggedIn ? const MapScreen() : const LoginScreen(),
        routes: {
          '/home': (_) => const MapScreen(),
          '/admin_panel': (_) => const AdminScreen(),
          '/admin_dashboard': (_) => const AdminDashboardScreen(),
          '/admin/floor_plan': (_) => const FloorPlanScreen(),
          '/admin/location_marking': (_) => const LocationMarkingScreen(),
          '/admin/geolocation_mapping': (_) => const GeolocationMappingScreen(),
          '/admin/location_testing': (_) => const LocationTestingScreen(),
          '/admin/training_data': (_) => const admin_training.TrainingDataScreen(),
          '/admin/model_retraining': (_) => const ModelRetrainingScreen(),
          '/admin/stats_dashboard': (_) => const StatsDashboardScreen(),
          '/digitized': (_) => const DigitizedMapView(),
          '/training_data': (_) => const legacy_training.TrainingDataScreen(),
          '/login': (_) => const LoginScreen(),
        },
      ),
    );
  }
}
