import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'app_state.dart';
import 'api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isAdminMode = false;
  bool _obscurePassword = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Keep-alive timer to prevent server from sleeping
  Timer? _keepAliveTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
    
    // Start keep-alive to wake up server
    _startKeepAlive();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _keepAliveTimer?.cancel();
    super.dispose();
  }
  
  void _startKeepAlive() {
    // Immediately ping the server to wake it up
    _pingServer();
    
    // Then ping every 20 seconds to keep it awake
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _pingServer();
    });
    
    print('🔄 Keep-alive started from login screen');
  }

  Future<void> _pingServer() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/health');
      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (resp.statusCode == 200) {
        print('💚 Server keep-alive: OK');
      } else {
        print('⚠️ Server keep-alive: ${resp.statusCode}');
      }
    } catch (e) {
      print('⚠️ Server keep-alive failed: $e');
    }
  }

  /// Validates credentials locally as fallback when server is unreachable
  Map<String, dynamic>? _localAuth(String username, String password) {
    // Admin check
    if (username == 'admin@admin.com' && password == 'KCETADMIN') {
      return {'role': 'admin', 'display_name': 'Admin'};
    }

    // Student check: 22ucs001 to 22ucs180, password = username
    final regex = RegExp(r'^22ucs(\d{3})$');
    final match = regex.firstMatch(username);
    if (match != null) {
      final num = int.parse(match.group(1)!);
      if (num >= 1 && num <= 180 && password == username) {
        return {'role': 'student', 'display_name': 'Student ${username.toUpperCase()}'};
      }
    }

    return null;
  }

  void _login() async {
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final appState = Provider.of<AppState>(context, listen: false);

    if (username.isEmpty || password.isEmpty) {
      _showError('Please enter username and password');
      return;
    }

    setState(() => _isLoading = true);

    // Try backend auth first
    Map<String, dynamic>? user;
    try {
      user = await ApiService.login(username, password);
    } catch (e) {
      print('Backend auth failed, trying local fallback: $e');
    }

    // Fallback to local auth if backend is unreachable
    user ??= _localAuth(username, password);

    if (!mounted) return;

    if (user != null) {
      final bool isAdmin = user['role'] == 'admin';
      final String displayName = user['display_name'] ?? username;

      // Save login to persistent storage via AppState
      appState.setUser(displayName, isAdmin);
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showError('Invalid credentials. Check your username and password.');
    }

    setState(() => _isLoading = false);
  }

  void _loginAsGuest() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setUser('Guest', false);
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with theme colors
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A1929), // Dark blue background
                  Color(0xFF132F4C), // Lighter blue accent
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo/Icon
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFF132F4C),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2979FF).withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2979FF).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 60,
                            color: Color(0xFF2979FF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'FindMyWay',
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Indoor Navigation System',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Main Login Card
                      Card(
                        elevation: 10,
                        color: const Color(0xFF132F4C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              // Role Switcher
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A1929),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _isAdminMode = false),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: !_isAdminMode ? const Color(0xFF2979FF) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Student',
                                              style: GoogleFonts.inter(
                                                color: !_isAdminMode ? Colors.white : Colors.white54,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _isAdminMode = true),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _isAdminMode ? const Color(0xFF2979FF) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Admin',
                                              style: GoogleFonts.inter(
                                                color: _isAdminMode ? Colors.white : Colors.white54,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Username Field
                              TextField(
                                controller: _usernameController,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                style: GoogleFonts.inter(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: _isAdminMode ? 'Admin Email' : 'Roll Number',
                                  labelStyle: GoogleFonts.inter(color: Colors.white60),
                                  hintText: _isAdminMode ? 'admin@admin.com' : '22ucs001',
                                  hintStyle: GoogleFonts.inter(color: Colors.white30),
                                  prefixIcon: Icon(
                                    _isAdminMode ? Icons.admin_panel_settings : Icons.person_outline,
                                    color: const Color(0xFF2979FF),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF0A1929),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF2979FF), width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Password Field
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _login(),
                                style: GoogleFonts.inter(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: GoogleFonts.inter(color: Colors.white60),
                                  hintText: _isAdminMode ? '' : 'Same as roll number',
                                  hintStyle: GoogleFonts.inter(color: Colors.white30),
                                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF2979FF)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF0A1929),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF2979FF), width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2979FF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          _isAdminMode ? 'ADMIN LOGIN' : 'SIGN IN',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Guest Option
                      TextButton(
                        onPressed: _loginAsGuest,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          'Continue as Guest',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isAdminMode 
                          ? 'Admin features enabled after login' 
                          : 'Students: Use your roll number as username & password',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
