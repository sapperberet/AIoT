import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_app/core/config/mqtt_config.dart';
import 'package:smart_home_app/core/providers/device_provider.dart';

void main() {
  test('Primary broker is first candidate', () {
    final candidates = MqttConfig.buildBrokerCandidates('192.168.1.3');
    expect(candidates.isNotEmpty, isTrue);
    expect(candidates.first, '192.168.1.3');
  });

  test('Gateway .1 is not auto-added', () {
    final candidates = MqttConfig.buildBrokerCandidates('192.168.1.2');
    expect(candidates, isNot(contains('192.168.1.1')));
  });

  test('Does not auto-add +1 neighbor candidate', () {
    final candidates = MqttConfig.buildBrokerCandidates('192.168.1.3');
    expect(candidates, isNot(contains('192.168.1.4')));
  });

  test('Legacy fallback addresses are excluded unless explicitly primary', () {
    final normal = MqttConfig.buildBrokerCandidates('192.168.1.3');
    expect(
        normal, isNot(contains(MqttConfig.previousDefaultLocalBrokerAddress)));
    expect(normal, isNot(contains(MqttConfig.legacyDefaultLocalBrokerAddress)));

    final legacyPrimary = MqttConfig.buildBrokerCandidates(
      MqttConfig.previousDefaultLocalBrokerAddress,
    );
    expect(
        legacyPrimary, contains(MqttConfig.previousDefaultLocalBrokerAddress));
    expect(legacyPrimary, contains(MqttConfig.legacyDefaultLocalBrokerAddress));
  });

  test('Dead fallback host is never persisted', () {
    final shouldPersist = DeviceProvider.shouldPersistFallbackBroker(
      retryBroker: '192.168.1.4',
      originalBrokerAddress: '192.168.1.3',
      currentBrokerAddress: '192.168.1.3',
      reachableCandidates: const ['192.168.1.3'],
    );

    expect(shouldPersist, isFalse);
  });

  test('Reachable non-original fallback host can be persisted', () {
    final shouldPersist = DeviceProvider.shouldPersistFallbackBroker(
      retryBroker: '192.168.1.5',
      originalBrokerAddress: '192.168.1.3',
      currentBrokerAddress: '192.168.1.3',
      reachableCandidates: const ['192.168.1.5'],
    );

    expect(shouldPersist, isTrue);
  });
}
