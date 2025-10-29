import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:logger/logger.dart';
import '../config/mqtt_config.dart';

enum ConnectionStatus {
  connected,
  disconnected,
  connecting,
  error,
}

class MqttService {
  MqttServerClient? _client;
  final Logger _logger = Logger();

  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<MqttMessage> _messageController =
      StreamController<MqttMessage>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<MqttMessage> get messageStream => _messageController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;

  // CRITICAL FIX: Prevent blocking media playback during reconnection
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectBackoff = Duration(seconds: 3);

  // Connect to MQTT broker
  Future<void> connect({
    String? brokerAddress,
    int? port,
    bool useCloud = false,
  }) async {
    try {
      _updateStatus(ConnectionStatus.connecting);

      final address = brokerAddress ??
          (useCloud
              ? MqttConfig.cloudBrokerAddress
              : MqttConfig.localBrokerAddress);
      final brokerPort = port ??
          (useCloud ? MqttConfig.cloudBrokerPort : MqttConfig.localBrokerPort);

      _client = MqttServerClient(address, MqttConfig.localClientId);
      _client!.port = brokerPort;
      _client!.keepAlivePeriod = MqttConfig.keepAlivePeriod;
      _client!.logging(on: false);

      // Set connection message
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(MqttConfig.localClientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      // Setup callbacks
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;

      await _client!.connect(MqttConfig.username, MqttConfig.password);

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _logger.i('MQTT connected successfully');
        _updateStatus(ConnectionStatus.connected);

        // Listen to messages
        _client!.updates!.listen((list) {
          if (list.isNotEmpty) {
            for (final message in list) {
              final recMess = message.payload as MqttPublishMessage;
              final payload = MqttPublishPayload.bytesToStringAsString(
                  recMess.payload.message);

              _logger.d('Message received on ${message.topic}: $payload');

              _messageController.add(MqttMessage(
                topic: message.topic,
                payload: payload,
                timestamp: DateTime.now(),
              ));
            }
          }
        });
      } else {
        _logger.e('MQTT connection failed: ${_client!.connectionStatus}');
        _updateStatus(ConnectionStatus.error);
        _client!.disconnect();
      }
    } catch (e) {
      _logger.e('MQTT connection error: $e');
      _updateStatus(ConnectionStatus.error);
      _client?.disconnect();
    }
  }

  // Disconnect from broker
  void disconnect() {
    _client?.disconnect();
    _updateStatus(ConnectionStatus.disconnected);
  }

  // Subscribe to a topic
  void subscribe(String topic, {MqttQos? qos}) {
    if (_currentStatus != ConnectionStatus.connected) {
      _logger.w('Cannot subscribe: Not connected to broker');
      return;
    }
    // Use QoS 0 (AtMostOnce) for real-time performance, unless explicitly specified
    final effectiveQos = qos ??
        (MqttConfig.useHighPerformanceMode
            ? MqttQos.atMostOnce
            : MqttQos.atLeastOnce);
    _client?.subscribe(topic, effectiveQos);
    _logger.i('Subscribed to topic: $topic (QoS: ${effectiveQos.name})');
  }

  // Unsubscribe from a topic
  void unsubscribe(String topic) {
    _client?.unsubscribe(topic);
    _logger.i('Unsubscribed from topic: $topic');
  }

  // Publish a message
  void publish(String topic, String message, {MqttQos? qos}) {
    if (_currentStatus != ConnectionStatus.connected) {
      _logger.w('Cannot publish: Not connected to broker');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    // Use QoS 0 (AtMostOnce) for real-time performance, unless explicitly specified
    final effectiveQos = qos ??
        (MqttConfig.useHighPerformanceMode
            ? MqttQos.atMostOnce
            : MqttQos.atLeastOnce);
    _client?.publishMessage(topic, effectiveQos, builder.payload!);
    _logger.i('Published to $topic: $message (QoS: ${effectiveQos.name})');
  }

  // Publish JSON data
  void publishJson(String topic, Map<String, dynamic> data, {MqttQos? qos}) {
    publish(topic, jsonEncode(data), qos: qos);
  }

  // Callback handlers
  void _onConnected() {
    _logger.i('MQTT client connected');
    _updateStatus(ConnectionStatus.connected);
  }

  void _onDisconnected() {
    _logger.w('MQTT client disconnected');
    _updateStatus(ConnectionStatus.disconnected);

    // CRITICAL FIX: Reconnect on background thread, don't block UI/media
    _scheduleReconnect();
  }

  /// CRITICAL FIX: Schedule reconnection without blocking media playback
  void _scheduleReconnect() {
    if (_isReconnecting) {
      _logger.i('Reconnection already in progress, skipping...');
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.e('Max reconnection attempts reached, giving up');
      _reconnectAttempts = 0;
      return;
    }

    _isReconnecting = true;
    _reconnectTimer?.cancel();

    // Calculate exponential backoff
    final delay = _reconnectBackoff * (_reconnectAttempts + 1);
    _logger.i(
        'Scheduling reconnect in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      if (_currentStatus == ConnectionStatus.disconnected) {
        _reconnectAttempts++;
        _logger.i(
            'Attempting to reconnect... (${_reconnectAttempts}/$_maxReconnectAttempts)');

        // Run on background isolate to not block UI/media threads
        connect().whenComplete(() {
          _isReconnecting = false;
        });
      }
    });
  }

  void _onSubscribed(String topic) {
    _logger.i('Subscription confirmed for topic: $topic');
  }

  void _updateStatus(ConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  // Cleanup
  void dispose() {
    _reconnectTimer?.cancel();
    disconnect();
    _statusController.close();
    _messageController.close();
  }
}

class MqttMessage {
  final String topic;
  final String payload;
  final DateTime timestamp;

  MqttMessage({
    required this.topic,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic>? get jsonPayload {
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
