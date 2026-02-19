import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/glass_card.dart';
import '../services/data_service.dart';
import 'dashboard_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final DataService _dataService = DataService();
  
  double? _lat;
  double? _lng;
  String _selectedCrop = "Rice";
  bool _isLocating = false;
  bool _isSaving = false;

  final List<Map<String, String>> _crops = [
    {"name": "Rice", "icon": "🌾"},
    {"name": "Tomato", "icon": "🍅"},
    {"name": "Cotton", "icon": "☁️"},
  ];

  Future<void> _fetchLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
        );
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching location: $e")),
      );
    } finally {
      setState(() => _isLocating = false);
    }
  }

  void _saveAndProceed() async {
    if (_nameController.text.isEmpty || _lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and fetch location")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      bool success = await _dataService.updateSettings(
        latitude: _lat!,
        longitude: _lng!,
        cropType: _selectedCrop,
        projectName: _nameController.text,
      );

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("project_name", _nameController.text);
        await prefs.setString("crop", _selectedCrop);
        await prefs.setDouble("lat", _lat!);
        await prefs.setDouble("lng", _lng!);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server error. Please try again.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e")),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  "Initialize System",
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Configure your smart field environment",
                  style: GoogleFonts.outfit(color: Colors.white70),
                ),
                const SizedBox(height: 40),
                _buildInput("Project Name", _nameController, "e.g. Smart Farm"),
                const SizedBox(height: 30),
                
                Text("Location", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: _isLocating ? null : _fetchLocation,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLocating ? "Fetching..." : (_lat != null ? "Location Secured" : "Fetch My Location"),
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            if (_lat != null)
                              Text("${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        const Spacer(),
                        if (_isLocating)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                Text("Select Crop", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 15),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _crops.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedCrop == _crops[index]["name"];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCrop = _crops[index]["name"]!),
                        child: Container(
                          margin: const EdgeInsets.only(right: 15),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? const Color(0xFF00E676).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF00E676) : Colors.white24,
                                    width: 2,
                                  ),
                                ),
                                child: Text(_crops[index]["icon"]!, style: const TextStyle(fontSize: 24)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _crops[index]["name"]!,
                                style: GoogleFonts.outfit(
                                  color: isSelected ? const Color(0xFF00E676) : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 60),
                GestureDetector(
                  onTap: _isSaving ? null : _saveAndProceed,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: _isSaving
                        ? const CircularProgressIndicator()
                        : Text(
                            "Initialize System",
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30),
              border: InputBorder.none,
            ),
          ),
        )
      ],
    );
  }
}
