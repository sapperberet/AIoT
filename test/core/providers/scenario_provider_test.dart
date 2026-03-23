import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_app/core/models/scenario_model.dart';
import 'package:smart_home_app/core/providers/scenario_provider.dart';
import 'package:smart_home_app/core/services/scenario_service.dart';

class FakeScenarioService extends ScenarioService {
  final List<Scenario> store;

  FakeScenarioService({List<Scenario>? initial})
      : store = List.from(initial ?? []);

  int getCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int toggleCalls = 0;

  Object? getError;
  Object? createError;
  Object? updateError;
  Object? deleteError;
  Object? toggleError;

  Completer<void>? getBlocker;

  @override
  Future<List<Scenario>> getScenarios() async {
    getCalls++;
    if (getBlocker != null) {
      await getBlocker!.future;
    }
    if (getError != null) {
      throw getError!;
    }
    return List<Scenario>.from(store);
  }

  @override
  Future<String> createScenario(Scenario scenario) async {
    createCalls++;
    if (createError != null) {
      throw createError!;
    }
    final created = scenario.copyWith(id: 'created-${createCalls}');
    store.add(created);
    return created.id!;
  }

  @override
  Future<void> updateScenario(String id, Scenario scenario) async {
    updateCalls++;
    if (updateError != null) {
      throw updateError!;
    }
    final i = store.indexWhere((s) => s.id == id);
    if (i >= 0) {
      store[i] = scenario.copyWith(id: id);
    }
  }

  @override
  Future<void> deleteScenario(String id) async {
    deleteCalls++;
    if (deleteError != null) {
      throw deleteError!;
    }
    store.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> toggleScenario(String id, bool active) async {
    toggleCalls++;
    if (toggleError != null) {
      throw toggleError!;
    }
    final i = store.indexWhere((s) => s.id == id);
    if (i >= 0) {
      store[i] = store[i].copyWith(isActive: active);
    }
  }
}

Scenario _scenario({
  required String id,
  required String name,
  bool active = true,
}) {
  return Scenario(
    id: id,
    name: name,
    isActive: active,
    trigger: ScenarioTrigger(
      type: ScenarioTriggerType.sensor,
      sensor: 'gas',
      condition: 'greater_than',
      value: 400,
    ),
    actions: [
      ScenarioAction(device: 'buzzer', action: 'on'),
    ],
  );
}

void main() {
  group('ScenarioProvider', () {
    test('loadScenarios loads endpoint data and clears error', () async {
      final service = FakeScenarioService(initial: [
        _scenario(id: '1', name: 'Gas Alert'),
      ]);
      final provider = ScenarioProvider(service: service);

      await provider.loadScenarios();

      expect(service.getCalls, 1);
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.scenarios.length, 1);
      expect(provider.scenarios.first.name, 'Gas Alert');
    });

    test('loadScenarios failure clears stale list and sets error', () async {
      final service = FakeScenarioService(initial: [
        _scenario(id: '1', name: 'Old Scenario'),
      ]);
      final provider = ScenarioProvider(service: service);

      await provider.loadScenarios();
      expect(provider.scenarios, isNotEmpty);

      service.getError = Exception('network down');
      await provider.loadScenarios();

      expect(provider.scenarios, isEmpty);
      expect(provider.error, isNotNull);
      expect(provider.isLoading, isFalse);
    });

    test('refreshFromEndpoint is skipped while load is in progress', () async {
      final service = FakeScenarioService(initial: [
        _scenario(id: '1', name: 'Initial'),
      ]);
      service.getBlocker = Completer<void>();
      final provider = ScenarioProvider(service: service);

      final pendingLoad = provider.loadScenarios();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.isLoading, isTrue);

      await provider.refreshFromEndpoint();

      expect(service.getCalls, 1);

      service.getBlocker!.complete();
      await pendingLoad;
    });

    test('createScenario does a single sync GET and updates list', () async {
      final service = FakeScenarioService();
      final provider = ScenarioProvider(service: service);
      final newScenario = _scenario(id: 'temp', name: 'Created Scenario');

      final ok = await provider.createScenario(newScenario);

      expect(ok, isTrue);
      expect(service.createCalls, 1);
      expect(service.getCalls, 1);
      expect(provider.error, isNull);
      expect(provider.scenarios.length, 1);
      expect(provider.scenarios.first.name, 'Created Scenario');
    });

    test('refresh right after create is blocked by cooldown (no duplicate GET)',
        () async {
      final service = FakeScenarioService();
      final provider = ScenarioProvider(service: service);

      final ok = await provider.createScenario(
        _scenario(id: 'temp', name: 'No Double Fetch'),
      );
      expect(ok, isTrue);
      expect(service.getCalls, 1);

      await provider.refreshFromEndpoint();
      expect(service.getCalls, 1);
    });

    test('refresh after cooldown performs another GET', () async {
      final service = FakeScenarioService(initial: [
        _scenario(id: '1', name: 'Before'),
      ]);
      final provider = ScenarioProvider(service: service);

      await provider.loadScenarios();
      expect(service.getCalls, 1);

      await Future<void>.delayed(const Duration(milliseconds: 2100));
      await provider.refreshFromEndpoint();

      expect(service.getCalls, 2);
    });

    test('updateScenario calls update then re-syncs once', () async {
      final service = FakeScenarioService(initial: [
        _scenario(id: '1', name: 'Old Name'),
      ]);
      final provider = ScenarioProvider(service: service);

      final ok = await provider.updateScenario(
        '1',
        _scenario(id: 'ignored', name: 'New Name'),
      );

      expect(ok, isTrue);
      expect(service.updateCalls, 1);
      expect(service.getCalls, 1);
      expect(provider.scenarios.single.name, 'New Name');
    });

    test('deleteScenario calls delete then re-syncs once', () async {
      final service = FakeScenarioService(initial: [
        _scenario(id: '1', name: 'Delete Me'),
      ]);
      final provider = ScenarioProvider(service: service);

      final ok = await provider.deleteScenario('1');

      expect(ok, isTrue);
      expect(service.deleteCalls, 1);
      expect(service.getCalls, 1);
      expect(provider.scenarios, isEmpty);
    });

    test('toggleScenario updates active state and re-syncs once', () async {
      final service = FakeScenarioService(initial: [
        _scenario(id: '1', name: 'Toggle', active: true),
      ]);
      final provider = ScenarioProvider(service: service);

      final ok = await provider.toggleScenario('1', false);

      expect(ok, isTrue);
      expect(service.toggleCalls, 1);
      expect(service.getCalls, 1);
      expect(provider.scenarios.single.isActive, isFalse);
    });

    test('mutation failure clears list and returns false', () async {
      final service = FakeScenarioService(initial: [
        _scenario(id: '1', name: 'Existing'),
      ]);
      final provider = ScenarioProvider(service: service);

      await provider.loadScenarios();
      expect(provider.scenarios.length, 1);

      service.createError = Exception('create failed');
      final ok = await provider.createScenario(
        _scenario(id: 'temp', name: 'Will Fail'),
      );

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.scenarios, isEmpty);
    });
  });
}
