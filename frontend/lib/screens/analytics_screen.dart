import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/irrigation_provider.dart';
import '../widgets/glass_card.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    const SizedBox(width: 20),
                    Text(
                      "Analytics",
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                
                _buildHeader("Moisture & Weather Trends"),
                const SizedBox(height: 15),
                SizedBox(
                  height: 280,
                  child: GlassCard(
                    padding: const EdgeInsets.all(15),
                    child: Consumer<IrrigationProvider>(
                      builder: (context, provider, child) {
                        return LineChart(
                          _buildDualLineData(
                            provider.history, 
                            (d) => d.moisture.toDouble(), 
                            (d) => d.precipitation,
                            const Color(0xFF00E5FF),
                            Colors.white38,
                            "Moisture",
                            "Rain"
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                _buildHeader("Temp vs Humidity"),
                const SizedBox(height: 15),
                SizedBox(
                  height: 280,
                  child: GlassCard(
                    padding: const EdgeInsets.all(15),
                    child: Consumer<IrrigationProvider>(
                      builder: (context, provider, child) {
                        return LineChart(
                          _buildDualLineData(
                            provider.history, 
                            (d) => d.temperature, 
                            (d) => d.humidity,
                            const Color(0xFFFF9100),
                            const Color(0xFF2196F3),
                            "Temp",
                            "Humid"
                          ),
                        );
                      },
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

  Widget _buildHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF00E5FF), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  LineChartData _buildDualLineData(
    List<dynamic> history, 
    double Function(dynamic) val1, 
    double Function(dynamic) val2,
    Color color1,
    Color color2,
    String label1,
    String label2
  ) {
    List<FlSpot> spots1 = [];
    List<FlSpot> spots2 = [];
    
    for (int i = 0; i < history.length; i++) {
      spots1.add(FlSpot(i.toDouble(), val1(history[i])));
      spots2.add(FlSpot(i.toDouble(), val2(history[i])));
    }

    if (spots1.isEmpty) {
      spots1 = [const FlSpot(0, 0)];
      spots2 = [const FlSpot(0, 0)];
    }

    return LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => const Color(0xFF203A43).withOpacity(0.8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                "${spot.barIndex == 0 ? label1 : label2}: ${spot.y.toStringAsFixed(1)}",
                GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
      ),
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        _lineData(spots1, color1, true),
        _lineData(spots2, color2, false),
      ],
    );
  }

  LineChartBarData _lineData(List<FlSpot> spots, Color color, bool filled) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: filled,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.2), Colors.transparent],
        ),
      ),
    );
  }
}
