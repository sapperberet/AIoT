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
  void subscribe(String topic, {MqttQos qos = MqttQos.atLeastOnce}) {
    if (_currentStatus != ConnectionStatus.connected) {
      _logger.w('Cannot subscribe: Not connected to broker');
      return;
    }
    _client?.subscribe(topic, qos);
    _logger.i('Subscribed to topic: $topic');
  }

  // Unsubscribe from a topic
  void unsubscribe(String topic) {
    _client?.unsubscribe(topic);
    _logger.i('Unsubscribed from topic: $topic');
  }

  // Publish a message
  void publish(String topic, String message,
      {MqttQos qos = MqttQos.atLeastOnce}) {
    if (_currentStatus != ConnectionStatus.connected) {
      _logger.w('Cannot publish: Not connected to broker');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client?.publishMessage(topic, qos, builder.payload!);
    _logger.i('Published to $topic: $message');
  }

  // Publish JSON data
  void publishJson(String topic, Map<String, dynamic> data,
      {MqttQos qos = MqttQos.atLeastOnce}) {
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

    // Auto-reconnect after delay
    Future.delayed(Duration(seconds: MqttConfig.reconnectDelay), () {
      if (_currentStatus == ConnectionStatus.disconnected) {
        _logger.i('Attempting to reconnect...');
        connect();
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
