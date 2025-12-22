/// MQTT Configuration for local and cloud brokers
///
/// Version 2 Integration (grad_project_backend-main(Version 2)):
/// - MediaMTX streaming server (RTSP/RTMP/HLS/WebRTC)
/// - n8n automation workflows
/// - Separate camera publisher service
/// - Improved face detection with RTSP stream consumption
class MqttConfig {
  // Local MQTT Broker Configuration (e.g., Mosquitto on Raspberry Pi)
  // NOTE: This is a fallback default. The actual IP should be discovered via beacon.
  static String _localBrokerAddress = '192.168.1.17'; // Fallback default

  // Getter and setter for dynamic IP address from beacon discovery
  static String get localBrokerAddress => _localBrokerAddress;
  static set localBrokerAddress(String address) {
    _localBrokerAddress = address;
    // Log the IP change for debugging
    print('🌐 MqttConfig: Broker address updated to $address');
  }

  static const int localBrokerPort = 1883;
  static const String localClientId = 'smart_home_app';

  // Cloud MQTT Broker Configuration (optional, e.g., HiveMQ Cloud)
  static const String cloudBrokerAddress =
      'your-cloud-broker.com'; // TODO: Replace
  static const int cloudBrokerPort = 8883; // SSL/TLS port
  static const bool useCloudBroker = false;

  // Authentication (if required) - Mosquitto is configured with allow_anonymous true
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

  // Door Topics (main_door, garage_door)
  static const String mainDoorStatusTopic = '$topicPrefix/main_door/status';
  static const String mainDoorCommandTopic = '$topicPrefix/main_door/command';
  static const String garageDoorStatusTopic = '$topicPrefix/garage_door/status';
  static const String garageDoorCommandTopic =
      '$topicPrefix/garage_door/command';

  // Window Topics (front_window, side_window)
  static const String windowStatusTopic = '$topicPrefix/+/window/status';
  static const String windowCommandTopic = '$topicPrefix/+/window/command';
  static String windowStatus(String windowId) =>
      '$topicPrefix/$windowId/status';
  static String windowCommand(String windowId) =>
      '$topicPrefix/$windowId/command';

  // Buzzer Topic
  static const String buzzerStatusTopic = '$topicPrefix/buzzer/status';
  static const String buzzerCommandTopic = '$topicPrefix/buzzer/command';

  // Legacy aliases for compatibility
  static const String doorStatusTopic = mainDoorStatusTopic;
  static const String doorCommandTopic = mainDoorCommandTopic;
  static const String garageStatusTopic = garageDoorStatusTopic;
  static const String garageCommandTopic = garageDoorCommandTopic;

  // Fan Topics (room-based with speed control: 0=off, 1=low, 2=medium, 3=high)
  static const String fanStatusTopic = '$topicPrefix/+/fan/status';
  static const String fanCommandTopic = '$topicPrefix/+/fan/command';
  static String roomFanStatusTopic(String room) =>
      '$topicPrefix/$room/fan/status';
  static String roomFanCommandTopic(String room) =>
      '$topicPrefix/$room/fan/command';

  // Light topics (room-based)
  static const String allLightsStatusTopic = '$topicPrefix/+/light/status';
  static const String allLightsCommandTopic = '$topicPrefix/+/light/command';

  // Device sync topics (for 3D visualization sync)
  static const String deviceSyncTopic = '$topicPrefix/sync/devices';
  static const String visualizationSyncTopic =
      '$topicPrefix/sync/visualization';

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

  // Sensor Topics (ESP32/IoT device data)
  static const String sensorDataTopic = '$topicPrefix/sensors/+/data';
  static const String temperatureTopic = '$topicPrefix/sensors/temperature';
  static const String humidityTopic = '$topicPrefix/sensors/humidity';
  static const String gasTopic = '$topicPrefix/sensors/gas';
  static const String ldrTopic = '$topicPrefix/sensors/ldr';
  static const String energyTopic = '$topicPrefix/sensors/energy';
  static const String motionSensorTopic = '$topicPrefix/sensors/motion';
  static const String smokeTopic = '$topicPrefix/sensors/smoke';
  static const String waterTopic = '$topicPrefix/sensors/water';
  static const String soundTopic = '$topicPrefix/sensors/sound';
  static const String pressureTopic = '$topicPrefix/sensors/pressure';
  static const String airQualityTopic = '$topicPrefix/sensors/air_quality';

  // Generic sensor data topic (wildcard for all sensors)
  static const String allSensorsTopic = '$topicPrefix/sensors/#';

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

  // Version 3: Voice & LLM Service ports
  static const int piperTtsPort = 5000; // Piper TTS (Arabic synthesis)
  static const int asrWhisperPort = 5003; // Faster-Whisper ASR
  static const int ollamaPort = 11434; // Ollama LLM API

  // External LLM (Colab/ngrok deployment)
  static const String externalLlmDomain = 'hugely-chief-dingo.ngrok-free.app';
  static const String externalLlmApiKey = 'sec';
  static const String externalLlmModel = 'qwen2.5:7b-instruct';

  // Keep alive and reconnection
  static const int keepAlivePeriod = 60;
  static const int reconnectDelay = 5; // seconds

  // Performance: QoS and stream settings
  static const bool useHighPerformanceMode =
      false; // Use QoS 1 (AtLeastOnce) for reliable delivery
  static const int streamDebounceMs = 100; // Debounce stream updates

  // ============================================================
  // n8n Workflow Integration Topics
  // These topics are used by n8n to trigger workflows and receive events
  // ============================================================

  // n8n Agent Topics (for AI chat via MQTT instead of HTTP)
  static const String agentRequestTopic = '$topicPrefix/agent/request';
  static const String agentResponseTopic = '$topicPrefix/agent/response';
  static const String agentStatusTopic = '$topicPrefix/agent/status';

  // n8n Door Control Topics (matches n8n workflow expectations)
  static const String n8nDoorCommandTopic = '$topicPrefix/door/command';
  static const String n8nDoorStatusTopic = '$topicPrefix/door/status';

  // App Status Topics (for n8n to know when app is connected)
  static const String appStatusTopic = '$topicPrefix/app/status';
  static const String appHeartbeatTopic = '$topicPrefix/app/heartbeat';

  // Wildcard topic for all home events (for n8n to listen to everything)
  static const String allHomeEventsTopic = '$topicPrefix/#';

  // Helper: Build n8n webhook URL
  static String get n8nAgentUrl =>
      'http://$localBrokerAddress:$n8nPort/api/agent';
  static String get n8nVoiceUrl =>
      'http://$localBrokerAddress:$n8nPort/api/voice';
  static String get n8nDoorUrl =>
      'http://$localBrokerAddress:$n8nPort/api/door';
  static String get n8nCameraFeedUrl =>
      'http://$localBrokerAddress:$n8nPort/api/camera-feed';
}
