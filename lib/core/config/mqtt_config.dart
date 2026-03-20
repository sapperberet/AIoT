import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// MQTT Configuration for local and cloud brokers
///
/// ESP32 Actuator Topics (ESP receives these):
/// - Fan: home/actuators/fan -> in/out/off
/// - Lights Floor1: home/actuators/lights/floor1 -> on/off
/// - Lights Floor2: home/actuators/lights/floor2 -> on/off
/// - Lights RGB: home/actuators/lights/rgb -> b <brightness> / c <color>
/// - Buzzer: home/actuators/buzzer -> on/off
/// - Garage Motor: home/actuators/motors/garage -> open/close
/// - Front Window: home/actuators/motors/frontwindow -> open/close
/// - Door Motor: home/actuators/motors/door -> open/close
/// - Gate Motor: home/actuators/motors/gate -> open/close
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
  static const String defaultLocalBrokerAddress =
      String.fromEnvironment('BACKEND_HOST', defaultValue: '192.168.1.3');
  static const String previousDefaultLocalBrokerAddress = '192.168.1.17';
  static const String legacyDefaultLocalBrokerAddress = '192.168.1.100';

  static String _localBrokerAddress =
      defaultLocalBrokerAddress; // Fallback default
  static const bool useDebugAdbReverseOverride =
      bool.fromEnvironment('USE_ADB_REVERSE', defaultValue: false);

  // Getter and setter for dynamic IP address from beacon discovery
  static String get localBrokerAddress {
    // In Android debug sessions with USB, adb reverse can map device localhost
    // to backend ports on the development machine.
    if (useDebugAdbReverseOverride &&
        kDebugMode &&
        !kIsWeb &&
        Platform.isAndroid) {
      return '127.0.0.1';
    }
    return _localBrokerAddress;
  }

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

  // RGB Light: b <brightness> / c <color_string>
  static const String lightRgbTopic = '$topicPrefix/actuators/lights/rgb';

  // Buzzer: on / off
  static const String buzzerCommandTopic = '$topicPrefix/actuators/buzzer';

  // Motors: open / close
  static const String garageMotorTopic = '$topicPrefix/actuators/motors/garage';
  static const String frontWindowMotorTopic =
      '$topicPrefix/actuators/motors/frontwindow';
  static const String doorMotorTopic = '$topicPrefix/actuators/motors/door';
  static const String gateMotorTopic = '$topicPrefix/actuators/motors/gate';

  // ============================================================
  // ESP32 SENSOR TOPICS (ESP publishes to these)
  // ============================================================

  static const String gasSensorTopic = '$topicPrefix/sensors/gas';
  static const String ldrSensorTopic = '$topicPrefix/sensors/ldr';
  static const String rainSensorTopic = '$topicPrefix/sensors/rain';
  static const String voltageSensorTopic = '$topicPrefix/sensors/voltage';
  static const String currentSensorTopic = '$topicPrefix/sensors/current';
  static const String humiditySensorTopic = '$topicPrefix/sensors/humidity';
  static const String temperatureSensorTopic = '$topicPrefix/sensors/temp';
  static const String flameSensorTopic = '$topicPrefix/sensors/flame';

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
    } else if (windowId == 'gate') {
      return gateMotorTopic;
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
  static const String doorStatusTopic =
      '$topicPrefix/actuators/motors/door/status';
  static const String windowStatusTopic =
      '$topicPrefix/actuators/motors/+/status';
  static const String garageStatusTopic =
      '$topicPrefix/actuators/motors/garage/status';
  static const String buzzerStatusTopic =
      '$topicPrefix/actuators/buzzer/status';
  static const String allLightsStatusTopic =
      '$topicPrefix/actuators/lights/+/status';
  static const String deviceSyncTopic = '$topicPrefix/device/sync';

  // Sensor topics (for subscribing)
  static const String temperatureTopic = temperatureSensorTopic;
  static const String humidityTopic = humiditySensorTopic;
  static const String gasTopic = gasSensorTopic;
  static const String ldrTopic = ldrSensorTopic;
  static const String voltageTopic = voltageSensorTopic;
  static const String currentTopic = currentSensorTopic;
  static const String flameTopic = flameSensorTopic;
  static const String rainTopic = rainSensorTopic;

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
  static const String beaconServiceName = 'server-beacon';
  static const List<String> beaconServiceNames = [
    'server-beacon',
    'face-broker',
  ];

  static bool isBeaconName(String? name) =>
      name != null && beaconServiceNames.contains(name);

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

  /// Build broker candidates from a primary IPv4 host.
  static List<String> buildBrokerCandidates(String primary) {
    final candidates = <String>[];

    bool isLegacyFallback(String value) =>
        value == previousDefaultLocalBrokerAddress ||
        value == legacyDefaultLocalBrokerAddress;

    void addIfValid(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      if (!candidates.contains(trimmed)) {
        candidates.add(trimmed);
      }
    }

    // Highest-priority candidates first.
    addIfValid(primary);

    // If a primary LAN IPv4 is available, include immediate neighbors.
    // This helps when DHCP shifts the host IP by one octet.
    final parts = primary.trim().split('.');
    if (parts.length == 4) {
      final octets = parts.map(int.tryParse).toList();
      final hasValidOctets = octets.every((o) => o != null);
      if (hasValidOctets) {
        final last = octets[3]!;
        // Avoid auto-probing .1 (commonly the router gateway), which creates
        // repeated health/MQTT failures in mobile LAN setups.
        if (last > 2) {
          addIfValid('${octets[0]}.${octets[1]}.${octets[2]}.${last - 1}');
        }
      }
    }

    addIfValid(_localBrokerAddress);
    addIfValid(defaultLocalBrokerAddress);

    // Keep legacy defaults out of automatic scans unless explicitly selected
    // as the primary/current broker. This avoids long failure cascades.
    if (isLegacyFallback(primary.trim())) {
      addIfValid(previousDefaultLocalBrokerAddress);
      addIfValid(legacyDefaultLocalBrokerAddress);
    }

    // In Android debug sessions, localhost/emulator host can be valid
    // fallback targets only when adb reverse override is explicitly enabled.
    if (kDebugMode && !kIsWeb && Platform.isAndroid) {
      if (useDebugAdbReverseOverride) {
        addIfValid('127.0.0.1');
        addIfValid('10.0.2.2');
      }
    }

    // Common container-host gateway fallback in local dev setups.
    if (useDebugAdbReverseOverride) {
      addIfValid('172.17.0.1');
    }

    return candidates;
  }
}
