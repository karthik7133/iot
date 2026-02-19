import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';

class DataService {
  static const String baseUrl = 'https://iot-0ts3.onrender.com';

  Future<SensorData?> fetchLatestData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/latest'));
      if (response.statusCode == 200) {
        return SensorData.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error fetching latest data: $e');
    }
    return null;
  }

  Future<IrrigationStats?> fetchStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stats'));
      if (response.statusCode == 200) {
        return IrrigationStats.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error fetching stats: $e');
    }
    return null;
  }

  Future<List<SensorData>> fetchHistory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/history'));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((dynamic item) => SensorData.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching history: $e');
    }
    return [];
  }

  Future<bool> updateSettings({
    double? latitude,
    double? longitude,
    required String cropType,
    String? projectName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'cropType': cropType,
          if (projectName != null) 'projectName': projectName,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating settings: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchSettings() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/settings'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching settings: $e');
    }
    return null;
  }
}
