import 'package:flutter/material.dart';

/// Legacy admin screen - redirects to new AdminDashboardScreen
class AdminScreen extends StatelessWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Automatically redirect to new dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/admin_dashboard');
    });

    return const Scaffold(
      backgroundColor: Color(0xFF0A1929),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2979FF),
        ),
      ),
    );
  }
}