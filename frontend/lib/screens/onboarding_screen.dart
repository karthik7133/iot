import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/glass_card.dart';
import 'setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      "title": "Smart Irrigation",
      "subtitle": "AI-powered water management for your crops, optimized for efficiency.",
      "image": "https://cdn-icons-png.flaticon.com/512/3043/3043543.png",
    },
    {
      "title": "Real-time Analytics",
      "subtitle": "Monitor soil health and save water instantly with precision sensors.",
      "image": "https://cdn-icons-png.flaticon.com/512/2933/2933824.png",
    },
    {
      "title": "Dynamic Crop AI",
      "subtitle": "Adaptive thresholds based on your crop type and local weather data.",
      "image": "https://cdn-icons-png.flaticon.com/512/1512/1512845.png",
    },
  ];

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
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 300,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.1),
                              blurRadius: 100,
                              spreadRadius: 20
                            )
                          ]
                        ),
                        child: Image.network(_pages[index]["image"]!, height: 250),
                      ),
                      const SizedBox(height: 60),
                      Text(
                        _pages[index]["title"]!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _pages[index]["subtitle"]!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          color: Colors.white70,
                          height: 1.5
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: _currentPage == index ? 30 : 10,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? const Color(0xFF00E5FF) : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: _currentPage == index ? [
                            BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.4), blurRadius: 10)
                          ] : []
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: GestureDetector(
                      onTap: () {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SetupScreen()),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (_currentPage == _pages.length - 1) ? const Color(0xFF00E5FF).withOpacity(0.3) : Colors.transparent,
                              blurRadius: 20,
                              spreadRadius: 2
                            )
                          ]
                        ),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              _currentPage == _pages.length - 1 ? "GET STARTED" : "CONTINUE",
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00E5FF),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
