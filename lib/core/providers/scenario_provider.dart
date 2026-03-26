import 'package:flutter/foundation.dart';
import '../models/scenario_model.dart';
import '../services/scenario_service.dart';

class ScenarioProvider with ChangeNotifier {
  final ScenarioService _service;
  static const Duration _refreshCooldown = Duration(seconds: 2);

  ScenarioProvider({required ScenarioService service}) : _service = service;

  List<Scenario> _scenarios = [];
  List<Scenario> get scenarios => List.unmodifiable(_scenarios);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;
  DateTime? _lastSyncedAt;

  Future<void> _syncFromEndpoint() async {
    _scenarios = await _service.getScenarios();
    _lastSyncedAt = DateTime.now();
  }

  // ── Load all scenarios ────────────────────────────────────

  Future<void> loadScenarios() async {
    _isLoading = true;
    _error = null;
    _scenarios = [];
    notifyListeners();

    try {
      await _syncFromEndpoint();
      _error = null;
    } catch (e) {
      _error = e.toString();
      // Keep UI strictly endpoint-driven: never show stale local scenarios.
      _scenarios = [];
      debugPrint('❌ ScenarioProvider load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshFromEndpoint() async {
    if (_isLoading) return;
    if (_lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _refreshCooldown) {
      return;
    }
    try {
      await _syncFromEndpoint();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _scenarios = [];
      notifyListeners();
      debugPrint('❌ ScenarioProvider refresh error: $e');
    }
  }

  // ── Create ────────────────────────────────────────────────

  Future<bool> createScenario(Scenario scenario) async {
    try {
      _error = null;
      await _service.createScenario(scenario);
      await _syncFromEndpoint();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _scenarios = [];
      notifyListeners();
      return false;
    }
  }

  // ── Update ────────────────────────────────────────────────

  Future<bool> updateScenario(String id, Scenario scenario) async {
    try {
      _error = null;
      await _service.updateScenario(id, scenario);
      await _syncFromEndpoint();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _scenarios = [];
      notifyListeners();
      return false;
    }
  }

  // ── Delete ────────────────────────────────────────────────

  Future<bool> deleteScenario(String id) async {
    try {
      _error = null;
      await _service.deleteScenario(id);
      await _syncFromEndpoint();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _scenarios = [];
      notifyListeners();
      return false;
    }
  }

  // ── Toggle ────────────────────────────────────────────────

  Future<bool> toggleScenario(String id, bool active) async {
    try {
      _error = null;
      await _service.toggleScenario(id, active);
      await _syncFromEndpoint();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _scenarios = [];
      notifyListeners();
      return false;
    }
  }
}
