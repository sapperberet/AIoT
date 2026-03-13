import 'dart:convert';
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
      final body = jsonEncode(scenario.toJson());
      debugPrint('📋 ScenarioService CREATE body: $body');

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/create'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
          '📋 ScenarioService CREATE ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final id = data['id'] as String?;
        if (id != null) return id;
        throw ScenarioApiException('No id returned from create', 200);
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

  // ── UPDATE scenario ───────────────────────────────────────

  Future<void> updateScenario(String id, Scenario scenario) async {
    try {
      final body = jsonEncode(scenario.toJson());
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
