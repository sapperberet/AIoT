/// MQTT Configuration for local and cloud brokers
///
/// ESP32 Actuator Topics (ESP receives these):
/// - Fan: home/actuators/fan -> in/out/on/off
/// - Lights Floor1: home/actuators/lights/floor1 -> on/off
/// - Lights Floor2: home/actuators/lights/floor2 -> on/off
/// - Lights Landscape: home/actuators/lights/landscape -> on/off
/// - Lights RGB: home/actuators/lights/rgb -> b <brightness> / c <color>
/// - Buzzer: home/actuators/buzzer -> on/off
/// - Garage Motor: home/actuators/motors/garage -> open/close
/// - Front Window: home/actuators/motors/frontwindow -> open/close
/// - Side Window: home/actuators/motors/sidewindow -> open/close
/// - Door Motor: home/actuators/motors/door -> open/close
///
/// ESP32 Sensor Topics (ESP sends these):
/// - Gas: home/sensors/gas
/// - LDR: home/sensors/ldr
/// - Rain: home/sensors/rain
/// - Voltage: home/sensors/voltage
/// - Current: home/sensors/current
/// - Humidity: home/sensors/humidity
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

  // ============================================================
  // ESP32 ACTUATOR TOPICS (ESP subscribes to these)
  // Messages are simple strings, NOT JSON
  // ============================================================

  // Fan: in / out / on / off
  static const String fanCommandTopic = '$topicPrefix/actuators/fan';

  // Lights: on / off
  static const String lightFloor1Topic = '$topicPrefix/actuators/lights/floor1';
  static const String lightFloor2Topic = '$topicPrefix/actuators/lights/floor2';
  static const String lightLandscapeTopic =
      '$topicPrefix/actuators/lights/landscape';

  // RGB Light: b <brightness> / c <color_string>
  static const String lightRgbTopic = '$topicPrefix/actuators/lights/rgb';

  // Buzzer: on / off
  static const String buzzerCommandTopic = '$topicPrefix/actuators/buzzer';

  // Motors: open / close
  static const String garageMotorTopic = '$topicPrefix/actuators/motors/garage';
  static const String frontWindowMotorTopic =
      '$topicPrefix/actuators/motors/frontwindow';
  static const String sideWindowMotorTopic =
      '$topicPrefix/actuators/motors/sidewindow';
  static const String doorMotorTopic = '$topicPrefix/actuators/motors/door';
  // Gate is same as door
  static const String gateMotorTopic = doorMotorTopic;

  // ============================================================
  // ESP32 SENSOR TOPICS (ESP publishes to these)
  // ============================================================

  static const String gasSensorTopic = '$topicPrefix/sensors/gas';
  static const String ldrSensorTopic = '$topicPrefix/sensors/ldr';
  static const String rainSensorTopic = '$topicPrefix/sensors/rain';
  static const String voltageSensorTopic = '$topicPrefix/sensors/voltage';
  static const String currentSensorTopic = '$topicPrefix/sensors/current';
  static const String humiditySensorTopic = '$topicPrefix/sensors/humidity';

  // ============================================================
  // LEGACY ALIASES (for backward compatibility with app code)
  // ============================================================

  // Door/Gate aliases
  static const String doorCommandTopic = doorMotorTopic;
  static const String mainDoorCommandTopic = doorMotorTopic;

  // Garage aliases
  static const String garageCommandTopic = garageMotorTopic;
  static const String garageDoorCommandTopic = garageMotorTopic;

  // Window aliases
  static String windowCommandTopic(String windowId) {
    if (windowId == 'front' || windowId == 'front_window') {
      return frontWindowMotorTopic;
    } else if (windowId == 'side' || windowId == 'side_window') {
      return sideWindowMotorTopic;
    }
    return '$topicPrefix/actuators/motors/$windowId';
  }

  // Light topic helper
  static String lightCommandTopic(String lightId) {
    switch (lightId) {
      case 'floor_1':
      case 'floor1':
        return lightFloor1Topic;
      case 'floor_2':
      case 'floor2':
        return lightFloor2Topic;
      case 'landscape':
        return lightLandscapeTopic;
      case 'rgb':
        return lightRgbTopic;
      default:
        return '$topicPrefix/actuators/lights/$lightId';
    }
  }

  // Alarm topics (for app-side notifications)
  static String alarmTopic(String location) => '$topicPrefix/$location/alarm';
  static const String fireAlarmTopic = 'home/+/fire_alarm';
  static const String motionAlarmTopic = 'home/+/motion';
  static const String doorAlarmTopic = 'home/+/door';

  // All sensors wildcard
  static const String allSensorsTopic = '$topicPrefix/sensors/#';

  // ============================================================
  // STATUS TOPICS (for receiving device state updates)
  // ============================================================

  // Device status topics
  static const String doorStatusTopic = '$topicPrefix/actuators/motors/door/status';
  static const String windowStatusTopic = '$topicPrefix/actuators/motors/+/status';
  static const String garageStatusTopic = '$topicPrefix/actuators/motors/garage/status';
  static const String buzzerStatusTopic = '$topicPrefix/actuators/buzzer/status';
  static const String allLightsStatusTopic = '$topicPrefix/actuators/lights/+/status';
  static const String deviceSyncTopic = '$topicPrefix/device/sync';

  // Sensor topics (for subscribing)
  static const String temperatureTopic = '$topicPrefix/sensors/temperature';
  static const String humidityTopic = humiditySensorTopic;
  static const String gasTopic = gasSensorTopic;
  static const String ldrTopic = ldrSensorTopic;
  static const String energyTopic = '$topicPrefix/sensors/energy';
  static const String motionSensorTopic = '$topicPrefix/sensors/motion';
  static const String smokeTopic = '$topicPrefix/sensors/smoke';
  static const String waterTopic = '$topicPrefix/sensors/water';
  static const String soundTopic = '$topicPrefix/sensors/sound';
  static const String pressureTopic = '$topicPrefix/sensors/pressure';
  static const String airQualityTopic = '$topicPrefix/sensors/air_quality';

  // n8n Door topics
  static const String n8nDoorStatusTopic = '$topicPrefix/door/status';
  static const String n8nDoorCommandTopic = '$topicPrefix/door/command';

  // Device status/command topic helpers
  static String deviceStatusTopic(String deviceId) =>
      '$topicPrefix/$deviceId/status';
  static String deviceCommandTopic(String deviceId) {
    // Map device IDs to actual ESP32 topics
    if (deviceId.contains('door') || deviceId == 'main_door') {
      return doorMotorTopic;
    } else if (deviceId.contains('garage')) {
      return garageMotorTopic;
    } else if (deviceId.contains('window')) {
      return windowCommandTopic(deviceId);
    } else if (deviceId.contains('light')) {
      return lightCommandTopic(deviceId.replaceAll('light_', ''));
    } else if (deviceId == 'fan') {
      return fanCommandTopic;
    } else if (deviceId == 'buzzer') {
      return buzzerCommandTopic;
    }
    return '$topicPrefix/actuators/$deviceId';
  }

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
  // ============================================================

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

  // n8n Agent Topics (for AI chat via MQTT instead of HTTP)
  static const String agentRequestTopic = '$topicPrefix/agent/request';
  static const String agentResponseTopic = '$topicPrefix/agent/response';
  static const String agentStatusTopic = '$topicPrefix/agent/status';

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
