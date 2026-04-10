import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../services/data_service.dart';

class IrrigationProvider with ChangeNotifier {
  final DataService _dataService = DataService();

  ZoneData _zoneData = ZoneData.empty();
  Map<String, dynamic>? _settings;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _timer;

  ZoneData get zoneData => _zoneData;
  Map<String, dynamic>? get settings => _settings;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;

  IrrigationProvider() {
    _init();
  }

  void _init() async {
    await refreshData();
    _isLoading = false;
    notifyListeners();

    // Poll every 3 seconds for a near real-time feel
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _silentRefresh());
  }

  // Called by the init timer — does NOT flip isLoading to avoid UI flicker
  Future<void> _silentRefresh() async {
    try {
      final zones = await _dataService.fetchLiveZones();
      if (zones != null) {
        _zoneData = zones;
        _hasError = false;
      }
    } catch (_) {
      _hasError = true;
    }
    notifyListeners();
  }

  // Full refresh — reloads both zone data AND settings (used on pull-to-refresh)
  Future<void> refreshData() async {
    _hasError = false;
    try {
      final results = await Future.wait([
        _dataService.fetchLiveZones(),
        _dataService.fetchSettings(),
      ]);
      if (results[0] != null) _zoneData = results[0] as ZoneData;
      if (results[1] != null) _settings = results[1] as Map<String, dynamic>;
    } catch (_) {
      _hasError = true;
    }
    notifyListeners();
  }

  Future<bool> updateCrop(String newCrop) async {
    final success = await _dataService.updateSettings(cropType: newCrop);
    if (success) await refreshData();
    return success;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
