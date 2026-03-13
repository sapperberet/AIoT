import 'package:flutter/foundation.dart';
import '../models/scenario_model.dart';
import '../services/scenario_service.dart';

class ScenarioProvider with ChangeNotifier {
  final ScenarioService _service;

  ScenarioProvider({required ScenarioService service}) : _service = service;

  List<Scenario> _scenarios = [];
  List<Scenario> get scenarios => List.unmodifiable(_scenarios);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // ── Load all scenarios ────────────────────────────────────

  Future<void> loadScenarios() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _scenarios = await _service.getScenarios();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ ScenarioProvider load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Create ────────────────────────────────────────────────

  Future<bool> createScenario(Scenario scenario) async {
    try {
      _error = null;
      final id = await _service.createScenario(scenario);
      _scenarios.add(scenario.copyWith(id: id));
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Update ────────────────────────────────────────────────

  Future<bool> updateScenario(String id, Scenario scenario) async {
    try {
      _error = null;
      await _service.updateScenario(id, scenario);
      final index = _scenarios.indexWhere((s) => s.id == id);
      if (index != -1) {
        _scenarios[index] = scenario.copyWith(id: id);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Delete ────────────────────────────────────────────────

  Future<bool> deleteScenario(String id) async {
    try {
      _error = null;
      await _service.deleteScenario(id);
      _scenarios.removeWhere((s) => s.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Toggle ────────────────────────────────────────────────

  Future<bool> toggleScenario(String id, bool active) async {
    try {
      _error = null;
      await _service.toggleScenario(id, active);
      final index = _scenarios.indexWhere((s) => s.id == id);
      if (index != -1) {
        _scenarios[index] = _scenarios[index].copyWith(isActive: active);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
