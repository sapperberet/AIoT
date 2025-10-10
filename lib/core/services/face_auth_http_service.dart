import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../config/mqtt_config.dart';
import '../models/face_auth_model.dart';

/// Service for handling face recognition authentication via HTTP REST API
/// This service works with the Docker-based backend (grad_project_backend-main(Linux))
class FaceAuthHttpService {
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

  // Track current request
  String? _currentRequestId;

  // Timeouts
  static const Duration _beaconDiscoveryTimeout = Duration(seconds: 10);
  static const Duration _authTimeout =
      Duration(seconds: 15); // Max time for face detection

  // HTTP client
  final http.Client _httpClient = http.Client();

  FaceAuthHttpService();

  void _updateStatus(FaceAuthStatus status) {
    _currentStatus = status;
    _statusController.add(status);
    _currentSession?.updateStatus(status);
  }

  /// Discover face recognition service via UDP beacon
  Future<FaceAuthBeacon?> discoverBeacon() async {
    _updateStatus(FaceAuthStatus.discovering);
    _logger.i('🔍 Starting beacon discovery...');

    try {
      // Create UDP socket for beacon discovery - bind to beacon port to receive broadcasts
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        MqttConfig.beaconPort, // Port 18830
      );
      socket.broadcastEnabled = true;

      _logger.i(
          '📡 UDP socket bound to port: ${socket.port} (listening for broadcasts)');

      final completer = Completer<FaceAuthBeacon?>();
      Timer? timeoutTimer;
      StreamSubscription? socketSubscription;

      // Set up timeout
      timeoutTimer = Timer(_beaconDiscoveryTimeout, () {
        _logger.w(
            '⏱️ Beacon discovery timeout after ${_beaconDiscoveryTimeout.inSeconds}s');
        socketSubscription?.cancel();
        socket.close();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      // Listen for beacon responses
      int packetCount = 0;
      socketSubscription = socket.listen((event) {
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
              _logger.e('❌ Error parsing beacon message: $e');
            }
          }
        }
      });

      // Passively listen for beacon broadcasts (sent every 2 seconds)
      _logger.i(
          '⏳ Waiting up to ${_beaconDiscoveryTimeout.inSeconds}s for beacon broadcast...');

      final result = await completer.future;

      // If discovery failed, try fallback to local broker address
      if (result == null) {
        _logger.w(
            '⚠️ Beacon discovery failed, trying fallback to ${MqttConfig.localBrokerAddress}');
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
      _logger.e('❌ Beacon discovery error: $e');

      // Try fallback even on exception
      _logger.w('⚠️ Attempting fallback to ${MqttConfig.localBrokerAddress}');
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

  /// Connect to the face recognition service (just validates beacon is available)
  Future<bool> connectToFaceService({FaceAuthBeacon? beacon}) async {
    try {
      _updateStatus(FaceAuthStatus.connecting);

      // Use provided beacon or discovered beacon
      final targetBeacon = beacon ?? _discoveredBeacon;

      if (targetBeacon == null || !targetBeacon.isValid) {
        _logger.e('❌ No valid beacon available for connection');
        _updateStatus(FaceAuthStatus.error);
        return false;
      }

      // Test connection to the face service API
      final apiUrl = 'http://${targetBeacon.ip}:8000/healthz';
      _logger.i('🔌 Testing connection to face service: $apiUrl');

      try {
        final response = await _httpClient
            .get(Uri.parse(apiUrl))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _logger.i('✅ Connected to face service at ${targetBeacon.ip}:8000');
          return true;
        } else {
          _logger.e('❌ Face service returned status: ${response.statusCode}');
          _updateStatus(FaceAuthStatus.error);
          return false;
        }
      } catch (e) {
        _logger.e('❌ Failed to connect to face service: $e');
        _updateStatus(FaceAuthStatus.error);
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error connecting to face service: $e');
      _updateStatus(FaceAuthStatus.error);
      return false;
    }
  }

  /// Request face authentication via HTTP REST API
  Future<FaceAuthResponse?> requestFaceAuth({
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (_discoveredBeacon == null || !_discoveredBeacon!.isValid) {
        _logger.e('❌ No valid beacon available');
        _updateStatus(FaceAuthStatus.error);
        return null;
      }

      _updateStatus(FaceAuthStatus.requestingScan);

      // Generate request
      final requestId = _uuid.v4();
      _currentRequestId = requestId;

      final request = FaceAuthRequest(
        requestId: requestId,
        userId: userId,
        deviceId: await _getDeviceId(),
        metadata: metadata,
      );

      // Create session
      _currentSession = FaceAuthSession(
        sessionId: requestId,
        request: request,
        status: FaceAuthStatus.requestingScan,
      );

      _logger.i('📸 Requesting face authentication: $requestId');

      // Update status to scanning
      _updateStatus(FaceAuthStatus.scanning);

      // Call face detection REST API
      final apiUrl = 'http://${_discoveredBeacon!.ip}:8000/detect-webcam';
      _logger.i('🌐 Calling face detection API: $apiUrl');

      try {
        // Prepare form data
        final requestData = {
          'persons_dir': '/data/persons',
          'webcam': '0',
          'max_seconds': '8', // Quick scan - 8 seconds max
          'stop_on_first': 'true', // Stop on first recognized face
          'model': 'hog', // Use HOG model (faster, CPU-friendly)
          'tolerance': '0.6',
          'frame_stride': '1', // Check every frame for faster detection
        };

        // Make HTTP POST request
        final response = await _httpClient
            .post(
              Uri.parse(apiUrl),
              body: requestData,
            )
            .timeout(_authTimeout);

        _logger.i('📡 Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body) as Map<String, dynamic>;
          _logger.i('📊 Detection result: $result');

          // Extract detected persons from names_seen
          final namesSeen = result['names_seen'] as Map<String, dynamic>?;
          final detectedPersons =
              namesSeen?.keys.where((name) => name != 'Unknown').toList() ?? [];

          FaceAuthResponse authResponse;

          if (detectedPersons.isNotEmpty) {
            // Face recognized successfully
            final detectedName = detectedPersons.first;
            _logger.i('✅ Face recognized: $detectedName');

            _updateStatus(FaceAuthStatus.success);

            authResponse = FaceAuthResponse(
              requestId: requestId,
              success: true,
              recognizedUserName: detectedName,
              confidence: 0.95, // TODO: Extract actual confidence from API
              timestamp: DateTime.now(),
            );
          } else {
            // No known face found
            _logger.w('⚠️ No recognized face detected');

            _updateStatus(FaceAuthStatus.failed);

            authResponse = FaceAuthResponse(
              requestId: requestId,
              success: false,
              errorMessage: 'No recognized face detected',
              timestamp: DateTime.now(),
            );
          }

          _currentSession?.setResponse(authResponse);
          _responseController.add(authResponse);
          _currentRequestId = null;
          return authResponse;
        } else {
          // API error
          _logger.e('❌ API returned status: ${response.statusCode}');
          _updateStatus(FaceAuthStatus.error);

          final authResponse = FaceAuthResponse(
            requestId: requestId,
            success: false,
            errorMessage:
                'Face detection service error: ${response.statusCode}',
            timestamp: DateTime.now(),
          );

          _currentSession?.setResponse(authResponse);
          _currentRequestId = null;
          return authResponse;
        }
      } on TimeoutException {
        _logger.w('⏱️ Face detection request timed out');
        _updateStatus(FaceAuthStatus.timeout);

        final authResponse = FaceAuthResponse(
          requestId: requestId,
          success: false,
          errorMessage: 'Face detection timed out',
          timestamp: DateTime.now(),
        );

        _currentSession?.updateStatus(
          FaceAuthStatus.timeout,
          error: 'Request timed out',
        );
        _currentRequestId = null;
        return authResponse;
      } catch (e) {
        _logger.e('❌ HTTP request error: $e');
        _updateStatus(FaceAuthStatus.error);

        final authResponse = FaceAuthResponse(
          requestId: requestId,
          success: false,
          errorMessage: 'Network error: $e',
          timestamp: DateTime.now(),
        );

        _currentSession?.updateStatus(
          FaceAuthStatus.error,
          error: e.toString(),
        );
        _currentRequestId = null;
        return authResponse;
      }
    } catch (e) {
      _logger.e('❌ Face authentication request error: $e');
      _updateStatus(FaceAuthStatus.error);
      _currentRequestId = null;
      return null;
    }
  }

  /// Get device ID for tracking
  Future<String> _getDeviceId() async {
    // In production, use device_info_plus or similar
    return 'flutter_device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Cancel current authentication request
  void cancelAuth() {
    if (_currentRequestId != null) {
      _logger.i('🛑 Cancelling authentication request: $_currentRequestId');
      _currentRequestId = null;
      _currentSession = null;
      _updateStatus(FaceAuthStatus.idle);
    }
  }

  /// Reset state
  void reset() {
    _currentRequestId = null;
    _currentSession = null;
    _updateStatus(FaceAuthStatus.idle);
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
    _statusController.close();
    _responseController.close();
    _beaconController.close();
  }
}
