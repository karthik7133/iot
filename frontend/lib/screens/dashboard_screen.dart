import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../providers/irrigation_provider.dart';
import '../models/sensor_data.dart';
import '../widgets/glass_card.dart';
import 'analytics_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours
const _bgDark   = Color(0xFF0F2027);
const _bgMid    = Color(0xFF203A43);
const _cyan     = Color(0xFF00E5FF);
const _green    = Color(0xFF00E676);
const _red      = Color(0xFFD50000);
const _orange   = Color(0xFFFF9100);

// ─────────────────────────────────────────────────────────────────────────────
// Liquid Wave CustomPainter
class _LiquidPainter extends CustomPainter {
  final double progress;   // 0.0 – 1.0
  final Color color;
  final double waveOffset; // animated phase offset

  _LiquidPainter({
    required this.progress,
    required this.color,
    required this.waveOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillHeight = size.height * (1.0 - progress.clamp(0.0, 1.0));

    // Draw wave
    final wavePaint = Paint()..color = color.withOpacity(0.85);
    final path = Path();

    path.moveTo(0, fillHeight);
    for (double x = 0; x <= size.width; x++) {
      final y = fillHeight +
          math.sin((x / size.width * 2 * math.pi) + waveOffset) * 6 +
          math.sin((x / size.width * 4 * math.pi) + waveOffset * 1.5) * 3;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, wavePaint);

    // Slightly brighter second wave layer
    final wavePaint2 = Paint()..color = color.withOpacity(0.4);
    final path2 = Path();
    path2.moveTo(0, fillHeight + 4);
    for (double x = 0; x <= size.width; x++) {
      final y = fillHeight +
          4 +
          math.sin((x / size.width * 2 * math.pi) + waveOffset + 1.0) * 5;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, wavePaint2);
  }

  @override
  bool shouldRepaint(_LiquidPainter old) =>
      old.progress != progress || old.waveOffset != waveOffset;
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Liquid Zone Card
class _ZoneCard extends StatefulWidget {
  final int zoneNumber;
  final int progress; // 0 – 100
  final bool gatesOpen;

  const _ZoneCard({
    required this.zoneNumber,
    required this.progress,
    required this.gatesOpen,
  });

  @override
  State<_ZoneCard> createState() => _ZoneCardState();
}

class _ZoneCardState extends State<_ZoneCard> with SingleTickerProviderStateMixin {
  late AnimationController _waveCtrl;
  double _waveOffset = 0;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _waveCtrl.addListener(() {
      setState(() => _waveOffset = _waveCtrl.value * 2 * math.pi);
    });
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int progress  = widget.progress.clamp(0, 100);
    final isComplete = progress >= 100;
    final isStopped  = !widget.gatesOpen;
    final borderColor = isComplete
        ? _green
        : (isStopped ? _orange : _cyan.withOpacity(0.5));
    final liquidColor = isComplete ? _green : _cyan;
    final progressF   = progress / 100.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: isComplete ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: (isComplete ? _green : _cyan).withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: isComplete ? 4 : 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          children: [
            // Background
            Container(color: _bgDark),

            // Liquid fill
            Positioned.fill(
              child: CustomPaint(
                painter: _LiquidPainter(
                  progress: progressF,
                  color: liquidColor,
                  waveOffset: _waveOffset,
                ),
              ),
            ),

            // Glass overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Text content
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Zone header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Zone ${widget.zoneNumber}",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 1.5,
                        ),
                      ),
                      _StatusPill(complete: isComplete, stopped: isStopped),
                    ],
                  ),

                  const Spacer(),

                  // Big percentage
                  Text(
                    "$progress%",
                    style: GoogleFonts.outfit(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? _green : Colors.white,
                    ),
                  ),

                  // Sub-label
                  Text(
                    isComplete
                        ? "✔  Irrigation Complete"
                        : isStopped
                            ? "⏸  Gates Closed"
                            : "Filling...",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isComplete
                          ? _green
                          : isStopped
                              ? _orange
                              : Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Thin progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressF.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(liquidColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Status pill badge
class _StatusPill extends StatelessWidget {
  final bool complete;
  final bool stopped;
  const _StatusPill({required this.complete, required this.stopped});

  @override
  Widget build(BuildContext context) {
    final Color color = complete ? _green : (stopped ? _orange : _cyan);
    final String label = complete ? "DONE" : (stopped ? "PAUSED" : "LIVE");
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Precipitation / weather banner
class _PrecipBanner extends StatelessWidget {
  final double precipitation;
  final bool gatesOpen;
  final int threshold;

  const _PrecipBanner({
    required this.precipitation,
    required this.gatesOpen,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final bool rainLikely = precipitation > threshold;
    final Color accent = rainLikely ? _orange : _green;
    final String text = rainLikely
        ? "Rain likely (${precipitation.toInt()}%) — Gates closed to save water"
        : "No rain (${precipitation.toInt()}%) — Irrigation active";

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(
            rainLikely ? Icons.umbrella_rounded : Icons.wb_sunny_rounded,
            color: accent,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rainLikely ? "Rain Alert" : "Clear Weather",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  text,
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            "${precipitation.toInt()}%",
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overall fill summary (average of both zones)
class _OverallProgress extends StatelessWidget {
  final int zone1;
  final int zone2;
  const _OverallProgress({required this.zone1, required this.zone2});

  @override
  Widget build(BuildContext context) {
    final avg = ((zone1 + zone2) / 2).round();
    final bool done = avg >= 100;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: avg / 100,
                    strokeWidth: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(done ? _green : _cyan),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  "$avg%",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Overall Field Progress",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                Text(
                  done
                      ? "All zones fully irrigated 🎉"
                      : "Zone 1: $zone1% · Zone 2: $zone2%",
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Dashboard Screen
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _projectName = "Smart Field";
  String _location    = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _projectName = prefs.getString("project_name") ?? "Smart Field";
      _location    = prefs.getString("location") ?? "Unknown Location";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgDark, _bgMid],
          ),
        ),
        child: Consumer<IrrigationProvider>(
          builder: (context, provider, _) {
            final data = provider.zoneData;

            return RefreshIndicator(
              onRefresh: provider.refreshData,
              backgroundColor: _bgMid,
              color: _cyan,
              child: CustomScrollView(
                slivers: [
                  SliverSafeArea(
                    sliver: SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            // ── Header Row ──────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Smart Irrigation",
                                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                                    ),
                                    Text(
                                      _projectName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    GlassCard(
                                      padding: const EdgeInsets.all(10),
                                      borderRadius: 12,
                                      child: const Icon(Icons.notifications_none, color: _cyan),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () => _showSettingsSheet(context, provider),
                                      child: const GlassCard(
                                        padding: EdgeInsets.all(10),
                                        borderRadius: 12,
                                        child: Icon(Icons.tune_rounded, color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Location & Date row
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: _cyan, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  _location,
                                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('EEE, MMM d').format(DateTime.now()),
                                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // ── Weather / Precipitation Banner ───────────
                            _PrecipBanner(
                              precipitation: data.precipitation,
                              gatesOpen:     data.gatesOpen,
                              threshold:     data.rainThreshold,
                            ),

                            const SizedBox(height: 22),

                            // ── Section Label ────────────────────────────
                            Text(
                              "Sequential Zone Irrigation",
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Live water flow progress per column",
                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
                            ),
                            const SizedBox(height: 14),

                            // ── 2-Column Zone Cards ──────────────────────
                            AspectRatio(
                              aspectRatio: 1.05,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ZoneCard(
                                      zoneNumber: 1,
                                      progress:   data.zone1Progress,
                                      gatesOpen:  data.gatesOpen,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _ZoneCard(
                                      zoneNumber: 2,
                                      progress:   data.zone2Progress,
                                      gatesOpen:  data.gatesOpen,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ── Overall Progress Summary ──────────────────
                            _OverallProgress(
                              zone1: data.zone1Progress,
                              zone2: data.zone2Progress,
                            ),

                            const SizedBox(height: 22),

                            // ── MQTT / Gate Status row ─────────────────
                            _buildGateStatusRow(data, provider),

                            const SizedBox(height: 28),

                            // ── Crop Settings shortcut ───────────────────
                            _buildCropInfo(provider),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
        ),
        label: Text("Insights", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.auto_graph),
        backgroundColor: _cyan.withOpacity(0.9),
        foregroundColor: Colors.black,
      ),
    );
  }

  // ── Gate Status ─────────────────────────────────────────────────────────────
  Widget _buildGateStatusRow(ZoneData data, IrrigationProvider provider) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data.gatesOpen ? _green : _orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Gate Status", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
                      Text(
                        data.gatesOpen ? "OPEN" : "CLOSED",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: data.gatesOpen ? _green : _orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.water, color: _cyan, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Rain Risk", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
                      Text(
                        data.rainLikely ? "HIGH" : "LOW",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: data.rainLikely ? _orange : _green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Crop Info ────────────────────────────────────────────────────────────────
  Widget _buildCropInfo(IrrigationProvider provider) {
    final settings = provider.settings;
    final crop = settings?['cropType'] ?? "—";
    final min  = settings?['minMoisture'];
    final max  = settings?['maxMoisture'];
    final range = (min != null && max != null) ? "$min% – $max%" : "—";

    return GestureDetector(
      onTap: () => _showSettingsSheet(context, provider),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.eco_rounded, color: _green, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Crop: $crop", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("Moisture target: $range", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, IrrigationProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CropSettingsSheet(provider: provider),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Crop Settings Bottom Sheet (preserved from original, lightly updated)
class _CropSettingsSheet extends StatefulWidget {
  final IrrigationProvider provider;
  const _CropSettingsSheet({required this.provider});

  @override
  _CropSettingsSheetState createState() => _CropSettingsSheetState();
}

class _CropSettingsSheetState extends State<_CropSettingsSheet> {
  String? _selectedCrop;
  bool _isSaving = false;

  final Map<String, Map<String, String>> _crops = {
    "Rice":   {"range": "60% – 80%", "icon": "🌾"},
    "Tomato": {"range": "40% – 60%", "icon": "🍅"},
    "Cotton": {"range": "30% – 50%", "icon": "🌿"},
  };

  @override
  void initState() {
    super.initState();
    _selectedCrop = widget.provider.settings?['cropType'];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: _bgDark.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50, height: 5,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 28),
          Text("System Settings", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          Text("Choose the active crop to set moisture targets.", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 28),

          _infoRow("Current Crop", _selectedCrop ?? "None"),
          _infoRow("Moisture Range", _crops[_selectedCrop]?['range'] ?? "—"),
          const SizedBox(height: 24),

          Text("Select Crop", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _crops.keys.map(_buildCropOption).toList(),
          ),

          const SizedBox(height: 36),

          GestureDetector(
            onTap: _isSaving || _selectedCrop == null ? null : _saveSettings,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(colors: [Color(0xFF00B09B), Color(0xFF00E676)]),
                boxShadow: [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text("SAVE SETTINGS", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white54)),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _buildCropOption(String crop) {
    final bool selected = _selectedCrop == crop;
    return GestureDetector(
      onTap: () => setState(() => _selectedCrop = crop),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 95,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? _green.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          border: Border.all(color: selected ? _green : Colors.white12, width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Text(_crops[crop]!['icon']!, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              crop,
              style: GoogleFonts.outfit(
                color: selected ? _green : Colors.white38,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSettings() async {
    if (_selectedCrop == null) return;
    setState(() => _isSaving = true);
    final success = await widget.provider.updateCrop(_selectedCrop!);
    setState(() => _isSaving = false);
    if (success && mounted) Navigator.pop(context);
  }
}
