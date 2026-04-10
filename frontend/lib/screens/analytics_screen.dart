import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/irrigation_provider.dart';
import '../widgets/glass_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lightweight model for a historical zone log snapshot
class _ZoneSnapshot {
  final int zone1Progress;
  final int zone2Progress;
  final double precipitation;
  final DateTime time;

  _ZoneSnapshot({
    required this.zone1Progress,
    required this.zone2Progress,
    required this.precipitation,
    required this.time,
  });

  factory _ZoneSnapshot.fromJson(Map<String, dynamic> json) => _ZoneSnapshot(
        zone1Progress:  ((json['zone1Progress'] ?? 0) as num).toInt(),
        zone2Progress:  ((json['zone2Progress'] ?? 0) as num).toInt(),
        precipitation:  ((json['precipitation'] ?? 0) as num).toDouble(),
        time: json['time'] != null
            ? DateTime.tryParse(json['time']) ?? DateTime.now()
            : DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _baseUrl = 'https://iot-0ts3.onrender.com';
  List<_ZoneSnapshot> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/history'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body) as List<dynamic>;
        setState(() => _history = raw.map((e) => _ZoneSnapshot.fromJson(e as Map<String, dynamic>)).toList());
      } else {
        setState(() => _error = 'Server returned ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadHistory,
            backgroundColor: const Color(0xFF203A43),
            color: const Color(0xFF00E5FF),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const GlassCard(
                          padding: EdgeInsets.all(10),
                          borderRadius: 12,
                          child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Text(
                        "Insights",
                        style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Live snapshot from provider
                  Consumer<IrrigationProvider>(
                    builder: (context, provider, _) {
                      final data = provider.zoneData;
                      return _buildLiveSnapshot(data.zone1Progress, data.zone2Progress, data.precipitation, data.gatesOpen);
                    },
                  ),

                  const SizedBox(height: 28),
                  _sectionHeader("Zone Progress History"),
                  const SizedBox(height: 14),

                  if (_isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                    ))
                  else if (_error != null)
                    _buildError()
                  else if (_history.isEmpty)
                    _buildEmpty()
                  else ...[
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 240,
                        child: LineChart(_buildProgressChart()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildChartLegend(),

                    const SizedBox(height: 28),
                    _sectionHeader("Precipitation History"),
                    const SizedBox(height: 14),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 200,
                        child: LineChart(_buildPrecipChart()),
                      ),
                    ),

                    const SizedBox(height: 28),
                    _sectionHeader("Session Stats"),
                    const SizedBox(height: 14),
                    _buildStats(),
                  ],
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Live Snapshot Row ───────────────────────────────────────────────────────
  Widget _buildLiveSnapshot(int z1, int z2, double precip, bool gates) {
    return Row(
      children: [
        Expanded(child: _statCard("Zone 1", "$z1%", const Color(0xFF00E5FF), Icons.water_drop)),
        const SizedBox(width: 12),
        Expanded(child: _statCard("Zone 2", "$z2%", const Color(0xFF00E676), Icons.water_drop_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _statCard("Rain", "${precip.toInt()}%", const Color(0xFFFF9100), Icons.cloudy_snowing)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) => GlassCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38)),
      ],
    ),
  );

  // ── Progress Chart ──────────────────────────────────────────────────────────
  LineChartData _buildProgressChart() {
    final List<FlSpot> z1 = [], z2 = [];
    for (int i = 0; i < _history.length; i++) {
      z1.add(FlSpot(i.toDouble(), _history[i].zone1Progress.toDouble()));
      z2.add(FlSpot(i.toDouble(), _history[i].zone2Progress.toDouble()));
    }
    return _dual(z1, z2, const Color(0xFF00E5FF), const Color(0xFF00E676), 100);
  }

  // ── Precip Chart ────────────────────────────────────────────────────────────
  LineChartData _buildPrecipChart() {
    final List<FlSpot> spots = List.generate(
      _history.length,
      (i) => FlSpot(i.toDouble(), _history[i].precipitation),
    );
    return _single(spots, const Color(0xFFFF9100), 100);
  }

  LineChartData _dual(
    List<FlSpot> s1, List<FlSpot> s2, Color c1, Color c2, double maxY) {
    return LineChartData(
      minY: 0, maxY: maxY,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
      ),
      titlesData: const FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [_bar(s1, c1, true), _bar(s2, c2, false)],
    );
  }

  LineChartData _single(List<FlSpot> spots, Color color, double maxY) {
    return LineChartData(
      minY: 0, maxY: maxY,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
      ),
      titlesData: const FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [_bar(spots, color, true)],
    );
  }

  LineChartBarData _bar(List<FlSpot> spots, Color color, bool filled) {
    return LineChartBarData(
      spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: filled,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.25), Colors.transparent],
        ),
      ),
    );
  }

  // ── Legend ──────────────────────────────────────────────────────────────────
  Widget _buildChartLegend() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _legendDot(const Color(0xFF00E5FF), "Zone 1"),
      const SizedBox(width: 20),
      _legendDot(const Color(0xFF00E676), "Zone 2"),
    ],
  );

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
    ],
  );

  // ── Stats ───────────────────────────────────────────────────────────────────
  Widget _buildStats() {
    final sessions = _history.length;
    final avgPrecip = _history.isEmpty ? 0.0 : _history.map((e) => e.precipitation).reduce((a, b) => a + b) / sessions;
    final rainSessions = _history.where((e) => e.precipitation > 80).length;

    return Row(
      children: [
        Expanded(child: _statCard("Snapshots", "$sessions", const Color(0xFF00E5FF), Icons.dataset)),
        const SizedBox(width: 12),
        Expanded(child: _statCard("Avg Rain", "${avgPrecip.toInt()}%", const Color(0xFFFF9100), Icons.water)),
        const SizedBox(width: 12),
        Expanded(child: _statCard("Rain Events", "$rainSessions", const Color(0xFF00E676), Icons.umbrella)),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) => Row(
    children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF00E5FF), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _buildError() => GlassCard(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFD50000)),
        const SizedBox(width: 12),
        Expanded(child: Text("Failed to load history: $_error", style: GoogleFonts.outfit(color: Colors.white70))),
      ],
    ),
  );

  Widget _buildEmpty() => GlassCard(
    padding: const EdgeInsets.all(20),
    child: Text("No history snapshots yet. Data is logged every 5 minutes.", style: GoogleFonts.outfit(color: Colors.white54)),
  );
}
