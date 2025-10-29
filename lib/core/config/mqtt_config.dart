/// MQTT Configuration for local and cloud brokers
///
/// Version 2 Integration (grad_project_backend-main(Version 2)):
/// - MediaMTX streaming server (RTSP/RTMP/HLS/WebRTC)
/// - n8n automation workflows
/// - Separate camera publisher service
/// - Improved face detection with RTSP stream consumption
class MqttConfig {
  // Local MQTT Broker Configuration (e.g., Mosquitto on Raspberry Pi)
  static const String localBrokerAddress =
      '192.168.1.7'; // Your computer's IP address
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

  // Face Recognition Authentication Topics
  static const String faceAuthRequestTopic = '$topicPrefix/auth/face/request';
  static const String faceAuthResponseTopic = '$topicPrefix/auth/face/response';
  static const String faceAuthStatusTopic = '$topicPrefix/auth/face/status';
  static const String faceAuthBeaconTopic = '$topicPrefix/auth/beacon';

  // Version 2: n8n workflow triggers
  static const String faceDetectTriggerTopic = 'face/trigger/cmd';
  static const String faceRecognizedTopic = '$topicPrefix/app/face-recognized';
  static const String faceUnrecognizedTopic =
      '$topicPrefix/app/face-unrecognized';

  // Beacon discovery settings
  static const int beaconPort = 18830;
  static const String beaconServiceName = 'face-broker';

  // Version 2: Service ports
  static const int n8nPort = 5678; // n8n automation
  static const int faceServicePort = 8000; // Face detection API
  static const int rtspPort = 8554; // MediaMTX RTSP
  static const int rtmpPort = 1935; // MediaMTX RTMP
  static const int hlsPort = 8888; // MediaMTX HLS
  static const int webrtcPort = 8889; // MediaMTX WebRTC

  // Keep alive and reconnection
  static const int keepAlivePeriod = 60;
  static const int reconnectDelay = 5; // seconds

  // Performance: QoS and stream settings
  static const bool useHighPerformanceMode =
      true; // Use QoS 0 (AtMostOnce) for real-time updates
  static const int streamDebounceMs = 100; // Debounce stream updates
}
