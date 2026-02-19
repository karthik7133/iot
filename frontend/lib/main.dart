import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/irrigation_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool hasSetup = prefs.containsKey("project_name");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IrrigationProvider()),
      ],
      child: const SmartIrrigationApp(),
    ),
  );
}

class SmartIrrigationApp extends StatelessWidget {
  const SmartIrrigationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Irrigation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        primaryColor: const Color(0x0000E5FF),
        textTheme: GoogleFonts.outfitTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF), // Neon Cyan
          secondary: Color(0xFF00E676), // Bright Green
          error: Color(0xFFD50000), // Warning Red
        ),
      ),
      home: FutureBuilder<bool>(
        future: _checkSetup(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return (snapshot.data == true) ? const DashboardScreen() : const OnboardingScreen();
        },
      ),
    );
  }

  Future<bool> _checkSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey("project_name");
  }
}
