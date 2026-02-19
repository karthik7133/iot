import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:intl/intl.dart';
import '../providers/irrigation_provider.dart';
import '../widgets/glass_card.dart';
import 'analytics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  String _projectName = "System";
  String _location = "Loading...";
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _projectName = prefs.getString("project_name") ?? "Smart Field";
      _location = prefs.getString("location") ?? "Unknown";
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
        child: Consumer<IrrigationProvider>(
          builder: (context, provider, child) {
            final data = provider.latestData;
            final isMotorOn = data?.motorStatus == "ON";

            return RefreshIndicator(
              onRefresh: provider.refreshData,
              backgroundColor: const Color(0xFF203A43),
              color: const Color(0xFF00E5FF),
              child: CustomScrollView(
                slivers: [
                  SliverSafeArea(
                    sliver: SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Good Morning,",
                                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
                                    ),
                                    Text(
                                      _projectName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                GlassCard(
                                  padding: const EdgeInsets.all(10),
                                  borderRadius: 12,
                                  child: Icon(Icons.notifications_none, color: Theme.of(context).colorScheme.primary),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => _showSettingsBottomSheet(context, provider),
                                  child: const GlassCard(
                                    padding: EdgeInsets.all(10),
                                    borderRadius: 12,
                                    child: Icon(Icons.settings, color: Colors.white70),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFF00E5FF), size: 16),
                                const SizedBox(width: 5),
                                Text(
                                  _location,
                                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('EEE, MMM d').format(DateTime.now()),
                                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            
                            // Hero: Digital Twin & Motor Status
                            _buildHeroSection(data, isMotorOn),
                            
                            const SizedBox(height: 30),
                            Text("Real-time Metrics", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 15),
                            
                            // 2x2 Grid
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                              childAspectRatio: 1.1,
                              children: [
                                _buildTile("Soil Moisture", "${data?.moisture ?? '--'}%", Icons.water_drop, const Color(0xFF00E5FF)),
                                _buildTile("Precipitation", "${data?.precipitation ?? '--'}%", Icons.cloudy_snowing, Colors.white70),
                                _buildTile("Temperature", "${data?.temperature ?? '--'}°C", Icons.thermostat, const Color(0xFFFF9100)),
                                _buildTile("Battery Health", "${data?.batteryLevel.toInt() ?? '--'}%", 
                                    (data?.batteryLevel ?? 100) > 30 ? Icons.battery_full : Icons.battery_alert, 
                                    (data?.batteryLevel ?? 100) > 30 ? const Color(0xFF00E676) : const Color(0xFFD50000)),
                              ],
                            ),
                            
                            const SizedBox(height: 30),
                            Text("AI Intelligence", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 15),
                            
                            // AI Insight Cards
                            _buildAIInsights(data, provider.stats?.waterSavedPercent ?? "0.0"),
                            
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen())),
        label: Text("Insights", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.auto_graph),
        backgroundColor: const Color(0xFF00E5FF).withOpacity(0.9),
      ),
    );
  }

  Widget _buildHeroSection(dynamic data, bool isMotorOn) {
    return Consumer<IrrigationProvider>(
      builder: (context, provider, child) {
        final settings = provider.settings;
        final crop = settings?['cropType'] ?? "Field";
        bool isDry = (data?.moisture ?? 50) < (settings?['minMoisture'] ?? 40);
        
        return GlassCard(
          padding: const EdgeInsets.all(25),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isMotorOn)
                    ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.4).animate(
                        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00E676).withOpacity(0.15),
                        ),
                      ),
                    ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isMotorOn ? const Color(0xFF00E676).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.local_florist,
                        size: 35,
                        color: isDry ? const Color(0xFF8D6E63) : const Color(0xFF00E676),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 25),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMotorOn ? "Motor Pulsing" : "$crop Status",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      isMotorOn ? "Hydrating your field..." : (isDry ? "Needs Attention" : "Ideal Conditions"),
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                    ),
                    if (isMotorOn)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            const Text("ACTIVE", style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildTile(String label, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildAIInsights(dynamic data, String waterSaved) {
    bool isHighRisk = data?.diseaseRisk == "HIGH";
    
    return Column(
      children: [
        // Disease Risk Card
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: isHighRisk ? [
              BoxShadow(color: const Color(0xFFD50000).withOpacity(0.3), blurRadius: 20, spreadRadius: 2)
            ] : []
          ),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: isHighRisk ? const Color(0xFFD50000) : const Color(0xFF00E676)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Disease Prediction", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(
                        isHighRisk ? "Warning: High humidity detected. Fungal risk elevated." : "Risk Level: Low. Continue monitoring.",
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(isHighRisk ? "HIGH" : "LOW", style: TextStyle(color: isHighRisk ? const Color(0xFFD50000) : const Color(0xFF00E676), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        
        // Yield & Water Saved
        Row(
          children: [
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Yield Health", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 5),
                    Text("${data?.yieldHealth.toInt() ?? '--'}%", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF00E676))),
                    const Text("Stable Monitoring", style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    CircularPercentIndicator(
                      radius: 25.0,
                      lineWidth: 4.0,
                      percent: (double.tryParse(waterSaved) ?? 0) / 100,
                      center: Text("${waterSaved.split('.')[0]}%", style: const TextStyle(fontSize: 8, color: Colors.white)),
                      progressColor: const Color(0xFF00E5FF),
                      backgroundColor: Colors.white10,
                      circularStrokeCap: CircularStrokeCap.round,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Saved", style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text("${waterSaved.split('.')[0]}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  void _showSettingsBottomSheet(BuildContext context, IrrigationProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CropSettingsSheet(provider: provider),
    );
  }
}

class _CropSettingsSheet extends StatefulWidget {
  final IrrigationProvider provider;
  const _CropSettingsSheet({required this.provider});

  @override
  _CropSettingsSheetState createState() => _CropSettingsSheetState();
}

class _CropSettingsSheetState extends State<_CropSettingsSheet> {
  String? _selectedCrop;
  bool _isSaving = false;

  final Map<String, String> _cropRanges = {
    "Rice": "60% - 80%",
    "Tomato": "40% - 60%",
    "Cotton": "30% - 50%",
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
        color: const Color(0xFF0F2027).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 30),
          Text("System Settings", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          Text("Configure your current field rotation.", style: GoogleFonts.outfit(color: Colors.white54)),
          const SizedBox(height: 30),
          
          _buildInfoRow("Current Crop", _selectedCrop ?? "None"),
          _buildInfoRow("Moisture Range", _cropRanges[_selectedCrop] ?? "--"),
          const SizedBox(height: 30),
          
          Text("Select New Crop", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _cropRanges.keys.map((crop) => _buildCropOption(crop)).toList(),
          ),
          
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _isSaving ? null : _saveSettings,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00E676).withOpacity(0.3), blurRadius: 20, spreadRadius: 2)
                ]
              ),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: _isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)))
                    : Text(
                        "SAVE CHANGES",
                        style: GoogleFonts.outfit(color: const Color(0xFF00E676), fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.white70)),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCropOption(String crop) {
    bool isSelected = _selectedCrop == crop;
    return GestureDetector(
      onTap: () => setState(() => _selectedCrop = crop),
      child: GlassCard(
        padding: const EdgeInsets.all(15),
        borderRadius: 16,
        opacity: isSelected ? 0.2 : 0.05,
        borderOpacity: isSelected ? 0.6 : 0.1,
        child: Column(
          children: [
            Icon(
              crop == "Rice" ? Icons.agriculture : (crop == "Tomato" ? Icons.restaurant : Icons.eco),
              color: isSelected ? const Color(0xFF00E676) : Colors.white38,
            ),
            const SizedBox(height: 10),
            Text(
              crop,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSettings() async {
    setState(() => _isSaving = true);
    final success = await widget.provider.updateCrop(_selectedCrop!);
    setState(() => _isSaving = false);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
