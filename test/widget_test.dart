import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_app/core/config/mqtt_config.dart';

void main() {
  test('Valid non-legacy primary broker is included as first candidate', () {
    final candidates = MqttConfig.buildBrokerCandidates('192.168.1.55');
    expect(candidates, isNotEmpty);
    expect(candidates.first, '192.168.1.55');
  });

  test('Gateway .1 is not auto-added', () {
    final candidates = MqttConfig.buildBrokerCandidates('192.168.1.55');
    expect(candidates, isNot(contains('192.168.1.1')));
  });

  test('Does not auto-add +1 neighbor candidate', () {
    final candidates = MqttConfig.buildBrokerCandidates('192.168.1.55');
    expect(candidates, isNot(contains('192.168.1.56')));
  });

  test('Default and legacy broker addresses are always excluded', () {
    final normal = MqttConfig.buildBrokerCandidates('192.168.1.55');
    expect(
        normal, isNot(contains(MqttConfig.previousDefaultLocalBrokerAddress)));
    expect(normal, isNot(contains(MqttConfig.legacyDefaultLocalBrokerAddress)));

    final legacyPrimary1 = MqttConfig.buildBrokerCandidates(
      MqttConfig.previousDefaultLocalBrokerAddress,
    );
    final legacyPrimary2 = MqttConfig.buildBrokerCandidates(
      MqttConfig.legacyDefaultLocalBrokerAddress,
    );
    expect(legacyPrimary1,
        isNot(contains(MqttConfig.previousDefaultLocalBrokerAddress)));
    expect(legacyPrimary2,
        isNot(contains(MqttConfig.legacyDefaultLocalBrokerAddress)));
  });

  test('Default primary broker is excluded under beacon-only policy', () {
    final candidates =
        MqttConfig.buildBrokerCandidates(MqttConfig.defaultLocalBrokerAddress);
    expect(candidates, isEmpty);
  });
}
