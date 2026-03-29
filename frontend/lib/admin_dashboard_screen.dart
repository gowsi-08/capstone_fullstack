import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isRailExpanded = true;
  String _locationMode = 'wifi'; // 'wifi' or 'gps'
  bool _isLoadingMode = true;

  final List<DashboardCard> _cards = [
    DashboardCard(
      title: 'Floor Plan Management',
      subtitle: 'Upload and manage floor maps',
      icon: Icons.map,
      color: const Color(0xFF2979FF),
      route: '/admin/floor_plan',
    ),
    DashboardCard(
      title: 'Location Marking',
      subtitle: 'Mark and edit room positions',
      icon: Icons.location_on,
      color: const Color(0xFF00BCD4),
      route: '/admin/location_marking',
    ),
    DashboardCard(
      title: 'Geolocation Mapping',
      subtitle: 'Assign GPS coordinates to nodes',
      icon: Icons.gps_fixed,
      color: const Color(0xFFE91E63),
      route: '/admin/geolocation_mapping',
    ),
    DashboardCard(
      title: 'Location Testing',
      subtitle: 'Test WiFi or GPS location prediction',
      icon: Icons.science,
      color: const Color(0xFFFF6D00),
      route: '/admin/location_testing',
    ),
    DashboardCard(
      title: 'Training Data Collection',
      subtitle: 'Collect WiFi fingerprints',
      icon: Icons.wifi,
      color: const Color(0xFF7C4DFF),
      route: '/admin/training_data',
    ),
    DashboardCard(
      title: 'Model Retraining',
      subtitle: 'Retrain ML prediction model',
      icon: Icons.model_training,
      color: const Color(0xFFFF6D00),
      route: '/admin/model_retraining',
    ),
    DashboardCard(
      title: 'Statistics & Analytics',
      subtitle: 'View system metrics',
      icon: Icons.bar_chart,
      color: const Color(0xFF00C853),
      route: '/admin/stats_dashboard',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animController.forward();
    _loadLocationMode();
  }
  
  Future<void> _loadLocationMode() async {
    final mode = await ApiService.getLocationMode();
    if (mounted) {
      setState(() {
        _locationMode = mode;
        _isLoadingMode = false;
      });
    }
  }
  
  Future<void> _toggleLocationMode() async {
    final newMode = _locationMode == 'wifi' ? 'gps' : 'wifi';
    final success = await ApiService.setLocationMode(newMode);
    
    if (success && mounted) {
      setState(() => _locationMode = newMode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location mode changed to ${newMode.toUpperCase()}',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: newMode == 'wifi' ? const Color(0xFF2979FF) : const Color(0xFF00C853),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Mobile layout - no sidebar, just cards
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _buildCardGrid(),
                ),
              ],
            );
          }
          
          // Tablet/Desktop layout with sidebar
          return Row(
            children: [
              _buildSidebar(appState),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _buildCardGrid(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar(AppState appState) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isRailExpanded ? 260 : 80,
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          
          // Admin Profile Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: _isRailExpanded ? 32 : 20,
                  backgroundColor: const Color(0xFF2979FF),
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: _isRailExpanded ? 32 : 20,
                    color: Colors.white,
                  ),
                ),
                if (_isRailExpanded) ...[
                  const SizedBox(height: 12),
                  Text(
                    appState.userType,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Administrator',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          
          // Navigation Items
          _buildNavItem(Icons.dashboard, 'Dashboard', true),
          _buildNavItem(Icons.settings, 'Settings', false),
          _buildNavItem(Icons.help_outline, 'Help', false),
          
          const Spacer(),
          
          // Toggle Rail Button
          InkWell(
            onTap: () => setState(() => _isRailExpanded = !_isRailExpanded),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isRailExpanded ? Icons.chevron_left : Icons.chevron_right,
                color: Colors.white,
              ),
            ),
          ),
          
          // Logout Button
          InkWell(
            onTap: () {
              appState.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, color: Colors.white, size: 20),
                  if (_isRailExpanded) ...[
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
        title: _isRailExpanded
            ? Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              )
            : null,
        onTap: () {},
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 44),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Dashboard',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your indoor navigation system',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Location Mode Toggle
          if (!_isLoadingMode) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeButton('WiFi', Icons.wifi, 'wifi'),
                  const SizedBox(width: 4),
                  _buildModeButton('GPS', Icons.gps_fixed, 'gps'),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.white),
            tooltip: 'Back to Map',
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModeButton(String label, IconData icon, String mode) {
    final isActive = _locationMode == mode;
    final color = mode == 'wifi' ? const Color(0xFF2979FF) : const Color(0xFF00C853);
    
    return GestureDetector(
      onTap: isActive ? null : _toggleLocationMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white54,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? Colors.white : Colors.white54,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 1200
              ? 3
              : constraints.maxWidth > 800
                  ? 2
                  : 1;
          
          return Wrap(
            spacing: 24,
            runSpacing: 24,
            children: List.generate(_cards.length, (index) {
              return AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  final delay = index * 0.1;
                  final animValue = Curves.easeOutCubic.transform(
                    ((_animController.value - delay) / (1 - delay)).clamp(0.0, 1.0),
                  );
                  
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - animValue)),
                    child: Opacity(
                      opacity: animValue,
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  width: (constraints.maxWidth - 32 * 2 - 24 * (crossAxisCount - 1)) /
                      crossAxisCount * 1.30, // Increased by 5%
                  child: _buildDashboardCard(_cards[index]),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard(DashboardCard card) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, card.route);
        },
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF132F4C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: card.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  card.icon,
                  size: 32,
                  color: card.color,
                ),
              ),
              const Spacer(),
              Text(
                card.title,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                card.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Open',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: card.color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: card.color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}
