import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/mqtt_config.dart';

enum ConnectionStatus {
  connected,
  disconnected,
  connecting,
  error,
}

/// Robust MQTT Service for persistent connection to Mosquitto broker
/// Designed for IoT communication with n8n automation backend
class MqttService {
  MqttServerClient? _client;

  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<AppMqttMessage> _messageController =
      StreamController<AppMqttMessage>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<AppMqttMessage> get messageStream => _messageController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;

  // Connection state tracking
  String? _currentBrokerAddress;
  int? _currentBrokerPort;
  bool _wasConnected = false;
  StreamSubscription? _messageSubscription;
  bool _isManualDisconnect = false;

  // Subscribed topics tracking - persist across reconnections
  final Set<String> _subscribedTopics = {};

  // CRITICAL: Robust reconnection handling
  Timer? _reconnectTimer;
  Timer? _reconnectUnblockTimer;
  Timer? _pingTimer;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _reconnectCooldownAfterMax = Duration(seconds: 90);
  static const Duration _pingInterval = Duration(seconds: 30);
  DateTime? _reconnectBlockedUntil;

  /// Connect to MQTT broker with robust error handling
  Future<bool> connect({
    String? brokerAddress,
    int? port,
    bool useCloud = false,
    bool scheduleReconnectOnFailure = true,
  }) async {
    // Prevent duplicate connection attempts
    if (_currentStatus == ConnectionStatus.connecting) {
      debugPrint('🔄 MQTT: Connection already in progress...');
      return false;
    }

    // If already connected to the same broker, return success
    final targetAddress = brokerAddress ??
        (useCloud
            ? MqttConfig.cloudBrokerAddress
            : MqttConfig.localBrokerAddress);
    final targetPort = port ??
        (useCloud ? MqttConfig.cloudBrokerPort : MqttConfig.localBrokerPort);

    if (_currentStatus == ConnectionStatus.connected &&
        _currentBrokerAddress == targetAddress &&
        _currentBrokerPort == targetPort) {
      debugPrint('✅ MQTT: Already connected to $targetAddress:$targetPort');
      return true;
    }

    // Disconnect existing connection if switching brokers
    if (_client != null) {
      debugPrint('🔌 MQTT: Disconnecting from previous broker...');
      await _disconnectCleanly();
    }

    try {
      _reconnectTimer?.cancel();
      _isReconnecting = false;
      _updateStatus(ConnectionStatus.connecting);
      _currentBrokerAddress = targetAddress;
      _currentBrokerPort = targetPort;

      debugPrint('🔗 MQTT: Connecting to $targetAddress:$targetPort...');

      // Create unique client ID with timestamp to avoid conflicts
      final clientId =
          '${MqttConfig.localClientId}_${DateTime.now().millisecondsSinceEpoch}';

      _client = MqttServerClient.withPort(targetAddress, clientId, targetPort);
      _client!.logging(on: false);

      // CRITICAL: Connection settings for persistent connection
      _client!.keepAlivePeriod = MqttConfig.keepAlivePeriod;
      _client!.autoReconnect =
          false; // Manual reconnect scheduling is handled below.
      _client!.resubscribeOnAutoReconnect = false;
      _client!.connectTimeoutPeriod = 5000; // 5 second timeout
      _client!.secure = false; // No TLS for local Mosquitto

      // Keep CONNECT packet minimal for maximum compatibility across
      // forwarded/network-translated paths.
      final connMessage =
          MqttConnectMessage().withClientIdentifier(clientId).startClean();

      _client!.connectionMessage = connMessage;

      // Setup callbacks BEFORE connecting
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onSubscribeFail = _onSubscribeFail;
      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onAutoReconnected = _onAutoReconnected;

      // Attempt connection
      final connResult = await _client!.connect(
        MqttConfig.username.isEmpty ? null : MqttConfig.username,
        MqttConfig.password.isEmpty ? null : MqttConfig.password,
      );

      if (connResult == null ||
          connResult.state != MqttConnectionState.connected) {
        debugPrint(
            '❌ MQTT: Connection failed - ${connResult?.state ?? 'null result'}');
        _updateStatus(ConnectionStatus.error);
        return false;
      }

      debugPrint(
          '✅ MQTT: Connected successfully to $targetAddress:$targetPort');
      _updateStatus(ConnectionStatus.connected);
      _wasConnected = true;
      _reconnectAttempts = 0;

      // Setup message listener
      _setupMessageListener();

      // Start ping timer to monitor connection health
      _startPingTimer();

      // Publish online status
      publish('home/app/status', 'online', retain: true);

      // Re-subscribe to previously subscribed topics
      if (_subscribedTopics.isNotEmpty) {
        debugPrint(
            '🔄 MQTT: Re-subscribing to ${_subscribedTopics.length} topics...');
        for (final topic in _subscribedTopics.toList()) {
          _subscribeInternal(topic);
        }
      }

      return true;
    } on SocketException catch (e) {
      debugPrint('❌ MQTT: Socket error - ${e.message}');
      _client?.disconnect();
      _client = null;
      _updateStatus(ConnectionStatus.error);
      if (scheduleReconnectOnFailure) {
        _scheduleReconnect();
      }
      return false;
    } on NoConnectionException catch (e) {
      debugPrint('❌ MQTT: No connection - $e');
      _client?.disconnect();
      _client = null;
      _updateStatus(ConnectionStatus.error);
      if (scheduleReconnectOnFailure) {
        _scheduleReconnect();
      }
      return false;
    } catch (e) {
      debugPrint('❌ MQTT: Connection error - $e');
      _updateStatus(ConnectionStatus.error);
      _client?.disconnect();
      _client = null;
      if (scheduleReconnectOnFailure) {
        _scheduleReconnect();
      }
      return false;
    }
  }

  /// Setup message listener with proper error handling
  void _setupMessageListener() {
    _messageSubscription?.cancel();
    _messageSubscription = _client?.updates?.listen(
      (messages) {
        if (messages.isEmpty) return;

        for (final message in messages) {
          try {
            final recMess = message.payload as MqttPublishMessage;
            final payload = MqttPublishPayload.bytesToStringAsString(
                recMess.payload.message);

            debugPrint('📩 MQTT: Received on ${message.topic}: $payload');

            _messageController.add(AppMqttMessage(
              topic: message.topic,
              payload: payload,
              timestamp: DateTime.now(),
            ));
          } catch (e) {
            debugPrint('⚠️ MQTT: Error processing message - $e');
          }
        }
      },
      onError: (error) {
        debugPrint('❌ MQTT: Message stream error - $error');
      },
      cancelOnError: false,
    );
  }

  /// Start ping timer to monitor connection health
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_currentStatus == ConnectionStatus.connected && _client != null) {
        // The MQTT client handles ping internally, but we can log connection status
        debugPrint(
            '💓 MQTT: Connection alive - ${_client!.connectionStatus?.state}');
      }
    });
  }

  // Disconnect from broker
  void disconnect() {
    _disconnectCleanly();
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// Clean disconnect handling
  Future<void> _disconnectCleanly() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _messageSubscription?.cancel();
    _isManualDisconnect = true;

    if (_client != null &&
        _client!.connectionStatus?.state == MqttConnectionState.connected) {
      try {
        publish('home/app/status', 'offline', retain: true);
        _client!.disconnect();
      } catch (e) {
        debugPrint('⚠️ MQTT: Error during disconnect - $e');
      }
    }
    _client = null;
    _isManualDisconnect = false;
  }

  /// Subscribe to a topic - tracks subscriptions for reconnection
  void subscribe(String topic, {MqttQos? qos}) {
    // Add to tracked topics
    _subscribedTopics.add(topic);

    if (_currentStatus != ConnectionStatus.connected) {
      debugPrint(
          '⚠️ MQTT: Not connected, topic $topic queued for subscription');
      return;
    }

    _subscribeInternal(topic, qos: qos);
  }

  /// Internal subscription method
  void _subscribeInternal(String topic, {MqttQos? qos}) {
    if (_client == null) return;

    try {
      // Use QoS 1 (AtLeastOnce) for reliable delivery
      final effectiveQos = qos ??
          (MqttConfig.useHighPerformanceMode
              ? MqttQos.atMostOnce
              : MqttQos.atLeastOnce);
      _client!.subscribe(topic, effectiveQos);
      debugPrint('📬 MQTT: Subscribed to $topic (QoS: ${effectiveQos.index})');
    } catch (e) {
      debugPrint('❌ MQTT: Failed to subscribe to $topic - $e');
    }
  }

  // Unsubscribe from a topic
  void unsubscribe(String topic) {
    _subscribedTopics.remove(topic);
    if (_client != null && _currentStatus == ConnectionStatus.connected) {
      try {
        _client!.unsubscribe(topic);
        debugPrint('📭 MQTT: Unsubscribed from $topic');
      } catch (e) {
        debugPrint('⚠️ MQTT: Error unsubscribing from $topic - $e');
      }
    }
  }

  /// Publish a message with optional retain flag
  void publish(String topic, String message,
      {MqttQos? qos, bool retain = false}) {
    if (_currentStatus != ConnectionStatus.connected || _client == null) {
      debugPrint('⚠️ MQTT: Cannot publish - not connected (topic: $topic)');
      return;
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);

      final effectiveQos = qos ??
          (MqttConfig.useHighPerformanceMode
              ? MqttQos.atMostOnce
              : MqttQos.atLeastOnce);

      _client!.publishMessage(topic, effectiveQos, builder.payload!,
          retain: retain);
      debugPrint('📤 MQTT: Published to $topic: $message');
    } catch (e) {
      debugPrint('❌ MQTT: Failed to publish to $topic - $e');
    }
  }

  // Publish JSON data
  void publishJson(String topic, Map<String, dynamic> data,
      {MqttQos? qos, bool retain = false}) {
    publish(topic, jsonEncode(data), qos: qos, retain: retain);
  }

  // Callback handlers
  void _onConnected() {
    debugPrint('✅ MQTT: onConnected callback triggered');
    _updateStatus(ConnectionStatus.connected);
    _reconnectAttempts = 0;
    _isReconnecting = false;
  }

  void _onDisconnected() {
    debugPrint('🔌 MQTT: onDisconnected callback triggered');

    if (_isManualDisconnect) {
      _updateStatus(ConnectionStatus.disconnected);
      return;
    }

    // Only update to disconnected if we're not auto-reconnecting
    if (!_isReconnecting) {
      _updateStatus(ConnectionStatus.disconnected);
    }

    // Schedule manual reconnect if auto-reconnect fails
    if (_wasConnected && _currentStatus != ConnectionStatus.connecting) {
      _scheduleReconnect();
    }
  }

  void _onSubscribed(String topic) {
    debugPrint('✅ MQTT: Subscription confirmed for: $topic');
  }

  void _onSubscribeFail(String topic) {
    debugPrint('❌ MQTT: Subscription failed for: $topic');
  }

  void _onAutoReconnect() {
    debugPrint('🔄 MQTT: Auto-reconnecting...');
    _isReconnecting = true;
    _updateStatus(ConnectionStatus.connecting);
  }

  void _onAutoReconnected() {
    debugPrint('✅ MQTT: Auto-reconnected successfully');
    _isReconnecting = false;
    _updateStatus(ConnectionStatus.connected);
    _reconnectAttempts = 0;

    // Re-setup message listener after auto-reconnect
    _setupMessageListener();
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_reconnectBlockedUntil != null &&
        DateTime.now().isBefore(_reconnectBlockedUntil!)) {
      final remaining = _reconnectBlockedUntil!.difference(DateTime.now());
      debugPrint(
          '⏸️ MQTT: Reconnect temporarily paused for ${remaining.inSeconds}s after max attempts');
      return;
    }

    if (_isReconnecting) {
      debugPrint('🔄 MQTT: Reconnection already in progress');
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
          '❌ MQTT: Max reconnection attempts ($_maxReconnectAttempts) reached');
      _reconnectBlockedUntil = DateTime.now().add(_reconnectCooldownAfterMax);
      _reconnectUnblockTimer?.cancel();
      _reconnectUnblockTimer = Timer(_reconnectCooldownAfterMax, () {
        _reconnectAttempts = 0;
        _isReconnecting = false;
        _reconnectBlockedUntil = null;

        if (!_isManualDisconnect &&
            _currentStatus != ConnectionStatus.connected) {
          _scheduleReconnect();
        }
      });
      _updateStatus(ConnectionStatus.error);
      return;
    }

    _isReconnecting = true;
    _reconnectTimer?.cancel();

    // Exponential backoff with jitter
    final delay = Duration(
      milliseconds: (_initialReconnectDelay.inMilliseconds *
              (1 << _reconnectAttempts.clamp(0, 5)))
          .clamp(_initialReconnectDelay.inMilliseconds,
              _maxReconnectDelay.inMilliseconds),
    );

    debugPrint(
        '⏳ MQTT: Scheduling reconnect in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      _reconnectAttempts++;
      debugPrint(
          '🔄 MQTT: Attempting reconnect ${_reconnectAttempts}/$_maxReconnectAttempts...');

      _isReconnecting = false; // Reset before attempting
      final success = await connect(
        brokerAddress: _currentBrokerAddress,
        port: _currentBrokerPort,
        scheduleReconnectOnFailure: false,
      );

      if (!success && _reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      }
    });
  }

  void _updateStatus(ConnectionStatus status) {
    if (_currentStatus != status) {
      debugPrint('📊 MQTT: Status changed: $_currentStatus -> $status');
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  /// Check if connected to a specific broker
  bool isConnectedTo(String address, int port) {
    return _currentStatus == ConnectionStatus.connected &&
        _currentBrokerAddress == address &&
        _currentBrokerPort == port;
  }

  /// Get connection info for debugging
  Map<String, dynamic> getConnectionInfo() {
    return {
      'status': _currentStatus.name,
      'brokerAddress': _currentBrokerAddress,
      'brokerPort': _currentBrokerPort,
      'subscribedTopics': _subscribedTopics.toList(),
      'reconnectAttempts': _reconnectAttempts,
    };
  }

  // Cleanup
  void dispose() {
    debugPrint('🧹 MQTT: Disposing service...');
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectUnblockTimer?.cancel();
    _messageSubscription?.cancel();
    disconnect();
    _statusController.close();
    _messageController.close();
  }
}

class AppMqttMessage {
  final String topic;
  final String payload;
  final DateTime timestamp;

  AppMqttMessage({
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

  @override
  String toString() => 'MqttMessage(topic: $topic, payload: $payload)';
}
