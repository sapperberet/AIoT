import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../config/mqtt_config.dart';
import '../models/face_auth_model.dart';
import 'mqtt_service.dart';

/// Service for handling face recognition authentication via MQTT
class FaceAuthService {
  final MqttService _mqttService;
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  // Current session tracking
  FaceAuthSession? _currentSession;
  FaceAuthBeacon? _discoveredBeacon;

  // Stream controllers
  final StreamController<FaceAuthStatus> _statusController =
      StreamController<FaceAuthStatus>.broadcast();
  final StreamController<FaceAuthResponse> _responseController =
      StreamController<FaceAuthResponse>.broadcast();
  final StreamController<FaceAuthBeacon> _beaconController =
      StreamController<FaceAuthBeacon>.broadcast();

  // Streams
  Stream<FaceAuthStatus> get statusStream => _statusController.stream;
  Stream<FaceAuthResponse> get responseStream => _responseController.stream;
  Stream<FaceAuthBeacon> get beaconStream => _beaconController.stream;

  // Current state
  FaceAuthStatus _currentStatus = FaceAuthStatus.idle;
  FaceAuthStatus get currentStatus => _currentStatus;
  FaceAuthSession? get currentSession => _currentSession;
  FaceAuthBeacon? get discoveredBeacon => _discoveredBeacon;

  // Track current request to ignore stale status messages
  String? _currentRequestId;
  double? _currentRequestTimestamp;

  // Timeouts
  static const Duration _beaconDiscoveryTimeout = Duration(seconds: 2);
  static const Duration _cameraInitTimeout =
      Duration(seconds: 27); // Camera initialization
  static const Duration _authResponseTimeout = Duration(
      seconds:
          50); // Total time for camera init + scanning + response (backend can take 30-40s + network delays)

  FaceAuthService({required MqttService mqttService})
      : _mqttService = mqttService {
    _init();
  }

  void _init() {
    // Listen to MQTT messages for face auth responses
    _mqttService.messageStream.listen((message) {
      _handleMqttMessage(message);
    });

    // Listen to MQTT connection status
    _mqttService.statusStream.listen((status) {
      if (status == ConnectionStatus.connected) {
        _subscribeToFaceAuthTopics();
      }
    });

    // Subscribe if already connected
    if (_mqttService.currentStatus == ConnectionStatus.connected) {
      _subscribeToFaceAuthTopics();
    }
  }

  void _subscribeToFaceAuthTopics() {
    _mqttService.subscribe(MqttConfig.faceAuthResponseTopic);
    _mqttService.subscribe(MqttConfig.faceAuthStatusTopic);
    _logger.i('Subscribed to face authentication topics');
  }

  /// Discover face recognition service via UDP beacon
  Future<FaceAuthBeacon?> discoverBeacon() async {
    _updateStatus(FaceAuthStatus.discovering);
    _logger.i('Starting beacon discovery...');

    try {
      // Create UDP socket for beacon discovery - MUST bind to beacon port to receive broadcasts
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        MqttConfig.beaconPort, // Bind to port 18830 to receive broadcasts
      );
      socket.broadcastEnabled = true;

      _logger.i(
          'UDP socket bound to port: ${socket.port} (listening for broadcasts)');

      final completer = Completer<FaceAuthBeacon?>();
      Timer? timeoutTimer;
      StreamSubscription? socketSubscription;

      // Set up timeout
      timeoutTimer = Timer(_beaconDiscoveryTimeout, () {
        _logger.w(
            'Beacon discovery timeout after ${_beaconDiscoveryTimeout.inSeconds}s');
        socketSubscription?.cancel();
        socket.close();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      // Listen for beacon responses
      int packetCount = 0;
      socketSubscription = socket.listen((event) {
        _logger.d('Socket event: $event');
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            packetCount++;
            _logger.i(
                '📦 Packet #$packetCount received from ${datagram.address.address}:${datagram.port}');
            try {
              final message = utf8.decode(datagram.data);
              _logger.i('📨 Message content: $message');
              final beaconData = jsonDecode(message) as Map<String, dynamic>;

              // Check if this is our face-broker beacon
              if (beaconData['name'] == MqttConfig.beaconServiceName) {
                final beacon = FaceAuthBeacon.fromJson(beaconData);
                _logger.i('✅ Beacon discovered: ${beacon.ip}:${beacon.port}');

                _discoveredBeacon = beacon;
                _beaconController.add(beacon);

                // Complete discovery
                timeoutTimer?.cancel();
                socketSubscription?.cancel();
                socket.close();
                if (!completer.isCompleted) {
                  completer.complete(beacon);
                }
              } else {
                _logger.w(
                    '⚠️ Received beacon with wrong name: ${beaconData['name']}');
              }
            } catch (e) {
              _logger.e('Error parsing beacon message: $e');
            }
          }
        }
      });

      // Note: We don't send WHO_IS anymore, just passively listen for periodic broadcasts
      // The beacon broadcasts every 2 seconds, so we should receive it within 30s
      _logger.i(
          '📡 Passively listening for beacon broadcasts on port ${MqttConfig.beaconPort}');
      _logger.i(
          '⏳ Waiting up to ${_beaconDiscoveryTimeout.inSeconds}s for beacon broadcast...');

      final result = await completer.future;

      // If discovery failed, try fallback to local broker address
      if (result == null) {
        _logger.w(
            'Beacon discovery failed, trying fallback to ${MqttConfig.localBrokerAddress}');
        final fallbackBeacon = FaceAuthBeacon(
          name: MqttConfig.beaconServiceName,
          ip: MqttConfig.localBrokerAddress,
          port: MqttConfig.localBrokerPort,
          discoveredAt: DateTime.now(),
        );
        _discoveredBeacon = fallbackBeacon;
        _beaconController.add(fallbackBeacon);
        _logger.i(
            '✅ Using fallback beacon: ${fallbackBeacon.ip}:${fallbackBeacon.port}');
        return fallbackBeacon;
      }

      return result;
    } catch (e) {
      _logger.e('Beacon discovery error: $e');

      // Try fallback even on exception
      _logger.w('Attempting fallback to ${MqttConfig.localBrokerAddress}');
      final fallbackBeacon = FaceAuthBeacon(
        name: MqttConfig.beaconServiceName,
        ip: MqttConfig.localBrokerAddress,
        port: MqttConfig.localBrokerPort,
        discoveredAt: DateTime.now(),
      );
      _discoveredBeacon = fallbackBeacon;
      _beaconController.add(fallbackBeacon);
      return fallbackBeacon;
    }
  }

  /// Connect to the face recognition MQTT broker
  Future<bool> connectToFaceBroker({FaceAuthBeacon? beacon}) async {
    try {
      _updateStatus(FaceAuthStatus.connecting);

      // Use provided beacon or discovered beacon
      final targetBeacon = beacon ?? _discoveredBeacon;

      if (targetBeacon == null || !targetBeacon.isValid) {
        _logger.e('No valid beacon available for connection');
        _updateStatus(FaceAuthStatus.error);
        return false;
      }

      // Connect to MQTT broker at beacon address
      await _mqttService.connect(
        brokerAddress: targetBeacon.ip,
        port: targetBeacon.port,
        useCloud: false,
      );

      if (_mqttService.currentStatus == ConnectionStatus.connected) {
        _logger.i(
            'Connected to face broker at ${targetBeacon.ip}:${targetBeacon.port}');
        return true;
      } else {
        _logger.e('Failed to connect to face broker');
        _updateStatus(FaceAuthStatus.error);
        return false;
      }
    } catch (e) {
      _logger.e('Error connecting to face broker: $e');
      _updateStatus(FaceAuthStatus.error);
      return false;
    }
  }

  /// Request face authentication
  Future<FaceAuthResponse?> requestFaceAuth({
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _updateStatus(FaceAuthStatus.requestingScan);

      // Generate request
      final requestId = _uuid.v4();
      final deviceId = await _getDeviceId();

      // Track current request to ignore stale status messages
      _currentRequestId = requestId;
      _currentRequestTimestamp = DateTime.now().millisecondsSinceEpoch /
          1000.0; // Unix timestamp in seconds

      final request = FaceAuthRequest(
        requestId: requestId,
        userId: userId,
        deviceId: deviceId,
        metadata: metadata,
      );

      // Create session
      _currentSession = FaceAuthSession(
        sessionId: requestId,
        request: request,
        status: FaceAuthStatus.requestingScan,
      );

      _logger.i('Requesting face authentication: $requestId');

      // Publish request to MQTT
      _mqttService.publishJson(
        MqttConfig.faceAuthRequestTopic,
        request.toJson(),
      );

      _updateStatus(FaceAuthStatus
          .requestingScan); // Start with requestingScan, backend will update to initializing

      // Wait for response with timeout
      final response = await _waitForResponse(requestId);

      if (response != null) {
        _currentSession?.setResponse(response);
        _updateStatus(
          response.success ? FaceAuthStatus.success : FaceAuthStatus.failed,
        );
        // Clear request tracking after completion
        _currentRequestId = null;
        _currentRequestTimestamp = null;
        return response;
      } else {
        _updateStatus(FaceAuthStatus.timeout);
        _currentSession?.updateStatus(
          FaceAuthStatus.timeout,
          error: 'Authentication request timed out',
        );
        // Clear request tracking after timeout
        _currentRequestId = null;
        _currentRequestTimestamp = null;
        return null;
      }
    } catch (e) {
      _logger.e('Face authentication request error: $e');
      _updateStatus(FaceAuthStatus.error);
      _currentSession?.updateStatus(
        FaceAuthStatus.error,
        error: e.toString(),
      );
      // Clear request tracking after error
      _currentRequestId = null;
      _currentRequestTimestamp = null;
      return null;
    }
  }

  /// Wait for authentication response
  Future<FaceAuthResponse?> _waitForResponse(String requestId) async {
    final completer = Completer<FaceAuthResponse?>();

    // Set up timeout
    Timer? timeoutTimer;
    StreamSubscription? responseSubscription;

    timeoutTimer = Timer(_authResponseTimeout, () {
      _logger.w('Auth response timeout for request: $requestId');
      responseSubscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    // Listen for response
    responseSubscription = _responseController.stream.listen((response) {
      if (response.requestId == requestId) {
        _logger.i('Received auth response for request: $requestId');
        timeoutTimer?.cancel();
        responseSubscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      }
    });

    return await completer.future;
  }

  /// Handle incoming MQTT messages
  void _handleMqttMessage(MqttMessage message) {
    try {
      // Handle face auth response
      if (message.topic == MqttConfig.faceAuthResponseTopic) {
        final jsonData = message.jsonPayload;
        if (jsonData != null) {
          final response = FaceAuthResponse.fromJson(jsonData);
          _logger.i('Face auth response received: ${response.requestId}');
          _responseController.add(response);
        }
      }

      // Handle face auth status updates
      if (message.topic == MqttConfig.faceAuthStatusTopic) {
        final jsonData = message.jsonPayload;
        if (jsonData != null) {
          _logger.i('Face auth status update: $jsonData');

          // Extract timestamp from status message
          final messageTimestamp = jsonData['timestamp'] as num?;

          // Debug log the comparison
          _logger.i(
              'Timestamp comparison: message=$messageTimestamp, currentRequest=$_currentRequestTimestamp');

          // Ignore stale messages (older than current request)
          if (_currentRequestTimestamp != null &&
              messageTimestamp != null &&
              messageTimestamp < _currentRequestTimestamp!) {
            _logger.w(
                '⚠️ IGNORING STALE status message: timestamp=$messageTimestamp < currentRequest=$_currentRequestTimestamp');
            return;
          }

          // Ignore status updates if no active request (e.g., after timeout)
          if (_currentRequestId == null) {
            _logger.w(
                '⚠️ IGNORING status update - no active request (already completed/timed out)');
            return;
          }

          // Parse status from backend
          final status = jsonData['status'] as String?;
          if (status == 'initializing') {
            _logger.i('✅ Updating to INITIALIZING status');
            _updateStatus(FaceAuthStatus.initializing);
          } else if (status == 'scanning') {
            _logger.i('✅ Updating to SCANNING status');
            _updateStatus(FaceAuthStatus.scanning);
          } else if (status == 'processing') {
            _logger.i('✅ Updating to PROCESSING status');
            _updateStatus(FaceAuthStatus.processing);
          }
        }
      }
    } catch (e) {
      _logger.e('Error handling MQTT message: $e');
    }
  }

  /// Get device ID (simplified for this implementation)
  Future<String> _getDeviceId() async {
    // In production, use device_info_plus to get actual device ID
    return 'mobile_app_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Update status and notify listeners
  void _updateStatus(FaceAuthStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  /// Cancel current authentication session
  void cancelAuth() {
    if (_currentSession != null && !_currentSession!.isCompleted) {
      _currentSession?.updateStatus(
        FaceAuthStatus.idle,
        error: 'Authentication cancelled by user',
      );
      _currentSession = null;
      _updateStatus(FaceAuthStatus.idle);
      _logger.i('Face authentication cancelled');
    }
  }

  /// Reset to idle state
  void reset() {
    _currentSession = null;
    _updateStatus(FaceAuthStatus.idle);
  }

  /// Dispose resources
  void dispose() {
    _statusController.close();
    _responseController.close();
    _beaconController.close();
  }
}
