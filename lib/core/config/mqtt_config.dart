/// MQTT Configuration for local and cloud brokers
class MqttConfig {
  // Local MQTT Broker Configuration (e.g., Mosquitto on Raspberry Pi)
  static const String localBrokerAddress =
      '192.168.1.100'; // TODO: Replace with your local broker IP
  static const int localBrokerPort = 1883;
  static const String localClientId = 'smart_home_app';

  // Cloud MQTT Broker Configuration (optional, e.g., HiveMQ Cloud)
  static const String cloudBrokerAddress =
      'your-cloud-broker.com'; // TODO: Replace
  static const int cloudBrokerPort = 8883; // SSL/TLS port
  static const bool useCloudBroker = false;

  // Authentication (if required)
  static const String username = ''; // Leave empty if no auth required
  static const String password = '';

  // Topic structure
  static const String topicPrefix = 'home';

  // Device topics
  static String deviceStatusTopic(String deviceId) =>
      '$topicPrefix/$deviceId/status';
  static String deviceCommandTopic(String deviceId) =>
      '$topicPrefix/$deviceId/command';

  // Room-specific topics
  static String roomLightStatusTopic(String room) =>
      '$topicPrefix/$room/light/status';
  static String roomLightCommandTopic(String room) =>
      '$topicPrefix/$room/light/set';

  // Alarm topics
  static String alarmTopic(String location) => '$topicPrefix/$location/alarm';
  static const String fireAlarmTopic = 'home/+/fire_alarm';
  static const String motionAlarmTopic = 'home/+/motion';
  static const String doorAlarmTopic = 'home/+/door';

  // Keep alive and reconnection
  static const int keepAlivePeriod = 60;
  static const int reconnectDelay = 5; // seconds
}
