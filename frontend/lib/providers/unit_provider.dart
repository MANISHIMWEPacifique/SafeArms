// Unit Provider - State management for units
// SafeArms Frontend

import 'package:flutter/foundation.dart';
import '../services/unit_service.dart';

class UnitProvider with ChangeNotifier {
  final UnitService _unitService = UnitService();

  // State
  List<dynamic> _units = [];
  dynamic _selectedUnit;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<dynamic> get units => _units;
  dynamic get selectedUnit => _selectedUnit;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all units
  Future<void> loadUnits() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _units = await _unitService.getAllUnits();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get unit by ID
  Future<void> getUnitById(String unitId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedUnit = await _unitService.getUnitById(unitId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create unit
  Future<bool> createUnit(Map<String, dynamic> unitData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newUnit = await _unitService.createUnit(unitData);
      _units.add(newUnit);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update unit
  Future<bool> updateUnit(String unitId, Map<String, dynamic> updates) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUnit = await _unitService.updateUnit(unitId, updates);
      final index = _units.indexWhere((u) => u['unit_id'] == unitId);
      if (index != -1) {
        _units[index] = updatedUnit;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Delete unit
  Future<bool> deleteUnit(String unitId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _unitService.deleteUnit(unitId);
      _units.removeWhere((u) => u['unit_id'] == unitId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
