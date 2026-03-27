import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api_service.dart';

class StatsDashboardScreen extends StatefulWidget {
  const StatsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<StatsDashboardScreen> createState() => _StatsDashboardScreenState();
}

class _StatsDashboardScreenState extends State<StatsDashboardScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _trainingStats;
  bool _isLoading = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await ApiService.getTrainingStats();
    if (mounted) {
      setState(() {
        _trainingStats = stats;
        _isLoading = false;
      });
      _animController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF132F4C),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics & Analytics',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'View system metrics',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Stats',
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF00C853),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading statistics...',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _trainingStats == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load statistics',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please try again',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Stats Grid
                      FadeTransition(
                        opacity: _animController,
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: 1.5,
                          children: [
                            _buildStatCard(
                              'Total Samples',
                              '${_trainingStats!["total_rows"] ?? 0}',
                              Icons.dataset_outlined,
                              const Color(0xFF2979FF),
                              'WiFi fingerprint records',
                            ),
                            _buildStatCard(
                              'Unique Locations',
                              '${_trainingStats!["total_locations"] ?? 0}',
                              Icons.location_on_outlined,
                              const Color(0xFF00BCD4),
                              'Mapped room positions',
                            ),
                            _buildStatCard(
                              'WiFi BSSIDs',
                              '${_trainingStats!["total_bssids"] ?? 0}',
                              Icons.wifi,
                              const Color(0xFF7C4DFF),
                              'Unique access points',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // System Health Card
                      FadeTransition(
                        opacity: _animController,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.health_and_safety_outlined,
                                          color: Color(0xFF00C853),
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'System Health',
                                          style: GoogleFonts.outfit(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _healthIndicator(
                                            'Model Status',
                                            'Trained',
                                            Icons.check_circle,
                                            const Color(0xFF00C853),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _healthIndicator(
                                            'Data Quality',
                                            _getDataQuality(),
                                            Icons.analytics,
                                            _getDataQualityColor(),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _healthIndicator(
                                            'Coverage',
                                            '${_trainingStats!["total_locations"] ?? 0} Locations',
                                            Icons.map_outlined,
                                            const Color(0xFF2979FF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Data Distribution Card
                      FadeTransition(
                        opacity: _animController,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.pie_chart_outline,
                                          color: Color(0xFF7C4DFF),
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Data Distribution',
                                          style: GoogleFonts.outfit(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    _distributionItem(
                                      'Average Samples per Location',
                                      _getAvgSamplesPerLocation(),
                                      Icons.trending_up,
                                      const Color(0xFF00BCD4),
                                    ),
                                    const SizedBox(height: 16),
                                    _distributionItem(
                                      'Average BSSIDs per Sample',
                                      _getAvgBSSIDsPerSample(),
                                      Icons.wifi_tethering,
                                      const Color(0xFF7C4DFF),
                                    ),
                                    const SizedBox(height: 16),
                                    _distributionItem(
                                      'Data Completeness',
                                      '${_getDataCompleteness()}%',
                                      Icons.check_circle_outline,
                                      const Color(0xFF00C853),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Recommendations Card
                      FadeTransition(
                        opacity: _animController,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.lightbulb_outline,
                                          color: Color(0xFFFF6D00),
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Recommendations',
                                          style: GoogleFonts.outfit(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    ..._getRecommendations().map((rec) => _recommendationItem(rec)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 40),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _healthIndicator(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _distributionItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6D00).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: Color(0xFFFF6D00),
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDataQuality() {
    final totalRows = _trainingStats!["total_rows"] ?? 0;
    final totalLocations = _trainingStats!["total_locations"] ?? 1;
    final avgSamples = totalRows / totalLocations;

    if (avgSamples >= 50) return 'Excellent';
    if (avgSamples >= 30) return 'Good';
    if (avgSamples >= 15) return 'Fair';
    return 'Poor';
  }

  Color _getDataQualityColor() {
    final quality = _getDataQuality();
    switch (quality) {
      case 'Excellent':
        return const Color(0xFF00C853);
      case 'Good':
        return const Color(0xFF64DD17);
      case 'Fair':
        return const Color(0xFFFF6D00);
      default:
        return const Color(0xFFD50000);
    }
  }

  String _getAvgSamplesPerLocation() {
    final totalRows = _trainingStats!["total_rows"] ?? 0;
    final totalLocations = _trainingStats!["total_locations"] ?? 1;
    return (totalRows / totalLocations).toStringAsFixed(1);
  }

  String _getAvgBSSIDsPerSample() {
    final totalBSSIDs = _trainingStats!["total_bssids"] ?? 0;
    final totalRows = _trainingStats!["total_rows"] ?? 1;
    return (totalBSSIDs / totalRows).toStringAsFixed(1);
  }

  int _getDataCompleteness() {
    final totalRows = _trainingStats!["total_rows"] ?? 0;
    final totalLocations = _trainingStats!["total_locations"] ?? 1;
    final avgSamples = totalRows / totalLocations;
    return ((avgSamples / 50) * 100).clamp(0, 100).toInt();
  }

  List<String> _getRecommendations() {
    final recommendations = <String>[];
    final totalRows = _trainingStats!["total_rows"] ?? 0;
    final totalLocations = _trainingStats!["total_locations"] ?? 1;
    final totalBSSIDs = _trainingStats!["total_bssids"] ?? 0;
    final avgSamples = totalRows / totalLocations;

    if (avgSamples < 15) {
      recommendations.add(
          'Collect more training data. Aim for at least 30-50 samples per location for better accuracy.');
    }

    if (totalBSSIDs < 10) {
      recommendations.add(
          'Limited WiFi coverage detected. Consider adding more access points or collecting data in different areas.');
    }

    if (totalLocations < 5) {
      recommendations.add(
          'Map more locations to improve navigation coverage across your building.');
    }

    if (avgSamples >= 30 && totalBSSIDs >= 15) {
      recommendations.add(
          'Your dataset looks good! Consider retraining the model to incorporate the latest data.');
    }

    if (recommendations.isEmpty) {
      recommendations.add(
          'System is operating normally. Continue collecting data to improve accuracy over time.');
    }

    return recommendations;
  }
}
