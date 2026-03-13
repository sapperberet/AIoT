import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/mqtt_config.dart';
import '../models/scenario_model.dart';

/// HTTP service for CRUD operations on the n8n scenario system.
class ScenarioService {
  String get _baseUrl =>
      'http://${MqttConfig.localBrokerAddress}:${MqttConfig.n8nPort}/run/scenarios';

  final http.Client _client = http.Client();

  // ── GET all scenarios ─────────────────────────────────────

  Future<List<Scenario>> getScenarios() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/get'))
          .timeout(const Duration(seconds: 15));

      debugPrint('📋 ScenarioService GET ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = response.body;
        if (body.isEmpty) return [];

        final decoded = jsonDecode(body);
        if (decoded is List) {
          return decoded
              .map((e) => Scenario.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      }
      throw ScenarioApiException(
          'Failed to load scenarios', response.statusCode);
    } catch (e) {
      if (e is ScenarioApiException) rethrow;
      debugPrint('❌ ScenarioService GET error: $e');
      rethrow;
    }
  }

  // ── CREATE scenario ───────────────────────────────────────

  Future<String> createScenario(Scenario scenario) async {
    try {
      _validateScenarioForWrite(scenario);
      final requestMap = _normalizeScenarioJson(scenario.toJson());
      final body = jsonEncode(requestMap);
      debugPrint('📋 ScenarioService CREATE body: $body');

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/create'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
          '📋 ScenarioService CREATE ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        final raw = response.body.trim();

        if (raw.isNotEmpty) {
          final dynamic data = jsonDecode(raw);
          if (data is Map<String, dynamic>) {
            final id = data['id'] as String?;
            if (id != null && id.isNotEmpty) return id;
          }
          if (data is String && data.isNotEmpty) {
            return data;
          }
        }

        // Some n8n flows return HTTP 200 with an empty body. Verify persistence
        // via GET and recover the created id when possible.
        final recoveredId = await _recoverCreatedScenarioId(requestMap);
        if (recoveredId != null) return recoveredId;

        throw ScenarioApiException(
          'Create endpoint returned an empty/invalid response and no scenario was persisted',
          200,
        );
      }
      throw ScenarioApiException(
        _parseError(response.body) ?? 'Failed to create scenario',
        response.statusCode,
      );
    } catch (e) {
      if (e is ScenarioApiException) rethrow;
      debugPrint('❌ ScenarioService CREATE error: $e');
      rethrow;
    }
  }

  Future<String?> _recoverCreatedScenarioId(
      Map<String, dynamic> expectedScenarioJson) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final scenarios = await getScenarios();
      final match = scenarios.where((s) {
        final actual = _normalizeScenarioJson(s.toJson());
        return _sameScenarioPayload(actual, expectedScenarioJson);
      }).toList();

      if (match.isNotEmpty) {
        final id = match.last.id;
        if (id != null && id.isNotEmpty) return id;
      }

      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return null;
  }

  // ── UPDATE scenario ───────────────────────────────────────

  Future<void> updateScenario(String id, Scenario scenario) async {
    try {
      _validateScenarioForWrite(scenario);
      final body = jsonEncode(_normalizeScenarioJson(scenario.toJson()));
      debugPrint('📋 ScenarioService UPDATE id=$id body: $body');

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/update?id=$id'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📋 ScenarioService UPDATE ${response.statusCode}');

      if (response.statusCode != 200) {
        throw ScenarioApiException(
          _parseError(response.body) ?? 'Failed to update scenario',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ScenarioApiException) rethrow;
      debugPrint('❌ ScenarioService UPDATE error: $e');
      rethrow;
    }
  }

  // ── DELETE scenario ───────────────────────────────────────

  Future<void> deleteScenario(String id) async {
    try {
      final response = await _client
          .delete(Uri.parse('$_baseUrl/delete?id=$id'))
          .timeout(const Duration(seconds: 15));

      debugPrint('📋 ScenarioService DELETE ${response.statusCode}');

      if (response.statusCode != 200) {
        throw ScenarioApiException(
          _parseError(response.body) ?? 'Failed to delete scenario',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ScenarioApiException) rethrow;
      debugPrint('❌ ScenarioService DELETE error: $e');
      rethrow;
    }
  }

  // ── TOGGLE scenario ───────────────────────────────────────

  Future<void> toggleScenario(String id, bool active) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/toggle?id=$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'active': active}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📋 ScenarioService TOGGLE ${response.statusCode}');

      if (response.statusCode != 200) {
        throw ScenarioApiException(
          _parseError(response.body) ?? 'Failed to toggle scenario',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ScenarioApiException) rethrow;
      debugPrint('❌ ScenarioService TOGGLE error: $e');
      rethrow;
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  String? _parseError(String body) {
    try {
      final data = jsonDecode(body);
      return data['error'] as String? ?? data['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _normalizeScenarioJson(Map<String, dynamic> input) {
    return _removeNulls(input) as Map<String, dynamic>;
  }

  dynamic _removeNulls(dynamic value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, dynamic item) {
        final cleaned = _removeNulls(item);
        if (cleaned != null) {
          result[key.toString()] = cleaned;
        }
      });
      return result;
    }
    if (value is List) {
      return value
          .map(_removeNulls)
          .where((item) => item != null)
          .toList(growable: false);
    }
    return value;
  }

  bool _sameScenarioPayload(
      Map<String, dynamic> left, Map<String, dynamic> right) {
    final leftWithoutId = Map<String, dynamic>.from(left)..remove('id');
    final rightWithoutId = Map<String, dynamic>.from(right)..remove('id');
    return jsonEncode(leftWithoutId) == jsonEncode(rightWithoutId);
  }

  void _validateScenarioForWrite(Scenario scenario) {
    final name = scenario.name.trim();
    if (name.isEmpty) {
      throw ScenarioApiException('Scenario name is required', 400);
    }
    if (scenario.actions.isEmpty) {
      throw ScenarioApiException('At least one action is required', 400);
    }

    final trigger = scenario.trigger;
    if (trigger.type == ScenarioTriggerType.sensor) {
      if (trigger.sensor == null || trigger.sensor!.isEmpty) {
        throw ScenarioApiException('Sensor trigger requires sensor name', 400);
      }
      if (trigger.condition == null || trigger.condition!.isEmpty) {
        throw ScenarioApiException('Sensor trigger requires condition', 400);
      }
      if (trigger.condition != 'changes' && trigger.value == null) {
        throw ScenarioApiException(
            'Sensor trigger value is required for this condition', 400);
      }
    }
  }

  void dispose() {
    _client.close();
  }
}

class ScenarioApiException implements Exception {
  final String message;
  final int statusCode;
  ScenarioApiException(this.message, this.statusCode);
  @override
  String toString() => 'ScenarioApiException($statusCode): $message';
}
