import 'dart:async';
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
  String _savingStatus = "Initializing...";

  final List<Map<String, String>> _crops = [
    {"name": "Rice", "icon": "🌾"},
    {"name": "Tomato", "icon": "🍅"},
    {"name": "Cotton", "icon": "☁️"},
  ];

  Future<void> _fetchLocation() async {
    setState(() => _isLocating = true);
    try {
      // 1. Check if location services are enabled on the device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Location services are disabled. Please enable GPS in device settings."),
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      // 2. Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Location permission denied. Please allow access."),
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  "Location permission permanently denied. Opening app settings…"),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: "Settings",
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      // 3. Permission granted — get position
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            _lat = position.latitude;
            _lng = position.longitude;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching location: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _saveAndProceed() async {
    if (_nameController.text.isEmpty || _lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and fetch location")),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _savingStatus = "Waking up server...";
    });

    try {
      // Step 1: Ping the server to wake it up (Render free tier cold start)
      await _dataService.pingServer();

      if (mounted) setState(() => _savingStatus = "Saving settings...");

      // Step 2: Save settings
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Server error. Please try again."),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Server is waking up (free tier). Please tap again in a moment ☀️"),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: "Retry",
              onPressed: _saveAndProceed,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('SocketException') ||
                e.toString().contains('Connection refused')
            ? "Cannot reach server. Check your internet connection."
            : "Error: ${e.toString().replaceAll('Exception: ', '')}";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _savingStatus,
                                style: GoogleFonts.outfit(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
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
