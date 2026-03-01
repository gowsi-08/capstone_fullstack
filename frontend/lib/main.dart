import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'splash_screen.dart';
import 'map_screen.dart';
import 'app_state.dart';
import 'db_helper.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import 'digitized_map_view.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.instance.initDB();
  runApp(const IndoorNavigationApp());
}

class IndoorNavigationApp extends StatelessWidget {
  const IndoorNavigationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Indoor Navigation',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
        ),
        home: const LoginScreen(),
        routes: {
          '/home': (_) => const MapScreen(),
          '/admin_panel': (_) => const AdminScreen(),
          '/digitized': (_) => const DigitizedMapView(),
        },
      ),
    );
  }
}
