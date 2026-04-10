import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';

class DataService {
  static const String baseUrl = 'https://iot-0ts3.onrender.com';
  // Render free tier cold starts can take 20-40s — use a generous timeout
  static const Duration _timeout = Duration(seconds: 45);

  /// Wake up the Render server (free tier sleeps after inactivity)
  Future<bool> pingServer() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ping')).timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch live zone progress + precipitation from the backend.
  Future<ZoneData?> fetchLiveZones() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/live-zones'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return ZoneData.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      // ignore — provider handles null gracefully
    }
    return null;
  }

  /// Fetch user/crop/location settings stored in the backend.
  Future<Map<String, dynamic>?> fetchSettings() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/settings'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Save updated settings (crop, location, project name) to the backend.
  Future<bool> updateSettings({
    double? latitude,
    double? longitude,
    required String cropType,
    String? projectName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/settings'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (latitude != null) 'latitude': latitude,
              if (longitude != null) 'longitude': longitude,
              'cropType': cropType,
              if (projectName != null) 'projectName': projectName,
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
