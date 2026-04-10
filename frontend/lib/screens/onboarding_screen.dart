import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/glass_card.dart';
import 'setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Smart Irrigation",
      "subtitle":
          "AI-powered water management for your crops, optimized for efficiency.",
      "icon": Icons.water_drop_rounded,
      "gradient": [Color(0xFF00E5FF), Color(0xFF0077B6)],
      "glowColor": Color(0xFF00E5FF),
    },
    {
      "title": "Real-time Analytics",
      "subtitle":
          "Monitor soil health and save water instantly with precision sensors.",
      "icon": Icons.analytics_rounded,
      "gradient": [Color(0xFF00E676), Color(0xFF00695C)],
      "glowColor": Color(0xFF00E676),
    },
    {
      "title": "Dynamic Crop AI",
      "subtitle":
          "Adaptive thresholds based on your crop type and local weather data.",
      "icon": Icons.eco_rounded,
      "gradient": [Color(0xFFFFD600), Color(0xFFFF6F00)],
      "glowColor": Color(0xFFFFD600),
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
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
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF0F2027)],
          ),
        ),
        child: Stack(
          children: [
            // Subtle background glow
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (_pages[_currentPage]["glowColor"] as Color)
                          .withOpacity(0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) =>
                  setState(() => _currentPage = index),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                final page = _pages[index];
                final List<Color> grad =
                    List<Color>.from(page["gradient"] as List);
                final Color glowColor = page["glowColor"] as Color;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated icon illustration
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                glowColor.withOpacity(0.18),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withOpacity(0.25),
                                blurRadius: 80,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    grad[0].withOpacity(0.25),
                                    grad[1].withOpacity(0.15),
                                  ],
                                ),
                                border: Border.all(
                                  color: grad[0].withOpacity(0.45),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                page["icon"] as IconData,
                                size: 80,
                                color: grad[0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                      // Gradient title
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: grad,
                        ).createShader(bounds),
                        child: Text(
                          page["title"] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        page["subtitle"] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Bottom controls
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
                          color: _currentPage == index
                              ? const Color(0xFF00E5FF)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: _currentPage == index
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF)
                                        .withOpacity(0.4),
                                    blurRadius: 10,
                                  )
                                ]
                              : [],
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
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SetupScreen()),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (_currentPage == _pages.length - 1)
                                  ? const Color(0xFF00E5FF).withOpacity(0.3)
                                  : Colors.transparent,
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              _currentPage == _pages.length - 1
                                  ? "GET STARTED"
                                  : "CONTINUE",
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00E5FF),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
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
