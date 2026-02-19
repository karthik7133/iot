import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../services/data_service.dart';

class IrrigationProvider with ChangeNotifier {
  final DataService _dataService = DataService();
  
  SensorData? _latestData;
  IrrigationStats? _stats;
  List<SensorData> _history = [];
  Map<String, dynamic>? _settings;
  bool _isLoading = true;
  Timer? _timer;

  SensorData? get latestData => _latestData;
  IrrigationStats? get stats => _stats;
  List<SensorData> get history => _history;
  Map<String, dynamic>? get settings => _settings;
  bool get isLoading => _isLoading;

  IrrigationProvider() {
    _init();
  }

  void _init() async {
    await refreshData();
    _isLoading = false;
    notifyListeners();
    
    // Silent polling every 10 seconds
    _timer = Timer.periodic(Duration(seconds: 10), (timer) async {
      await refreshData();
    });
  }

  Future<void> refreshData() async {
    final futures = await Future.wait([
      _dataService.fetchLatestData(),
      _dataService.fetchStats(),
      _dataService.fetchHistory(),
      _dataService.fetchSettings(),
    ]);

    _latestData = futures[0] as SensorData?;
    _stats = futures[1] as IrrigationStats?;
    _history = futures[2] as List<SensorData>;
    _settings = futures[3] as Map<String, dynamic>?;
    
    notifyListeners();
  }

  Future<bool> updateCrop(String newCrop) async {
    final success = await _dataService.updateSettings(cropType: newCrop);
    if (success) {
      await refreshData();
    }
    return success;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
