/// Face Recognition Authentication Models

/// Status of face authentication process
enum FaceAuthStatus {
  idle,
  discovering,
  connecting,
  requestingScan,
  scanning,
  processing,
  success,
  failed,
  timeout,
  error,
}

/// Beacon information for face recognition service
class FaceAuthBeacon {
  final String name;
  final String ip;
  final int port;
  final DateTime discoveredAt;

  FaceAuthBeacon({
    required this.name,
    required this.ip,
    required this.port,
    required this.discoveredAt,
  });

  factory FaceAuthBeacon.fromJson(Map<String, dynamic> json) {
    return FaceAuthBeacon(
      name: json['name'] as String? ?? '',
      ip: json['ip'] as String? ?? '',
      port: json['port'] as int? ?? 1883,
      discoveredAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ip': ip,
      'port': port,
      'discoveredAt': discoveredAt.toIso8601String(),
    };
  }

  bool get isValid => name.isNotEmpty && ip.isNotEmpty && port > 0;
}

/// Face authentication request sent to the computer vision system
class FaceAuthRequest {
  final String requestId;
  final String? userId; // Optional - for multi-user systems
  final String deviceId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  FaceAuthRequest({
    required this.requestId,
    this.userId,
    required this.deviceId,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      if (userId != null) 'userId': userId,
      'deviceId': deviceId,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory FaceAuthRequest.fromJson(Map<String, dynamic> json) {
    return FaceAuthRequest(
      requestId: json['requestId'] as String,
      userId: json['userId'] as String?,
      deviceId: json['deviceId'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Response from the computer vision system
class FaceAuthResponse {
  final String requestId;
  final bool success;
  final String? recognizedUserId;
  final String? recognizedUserName;
  final double? confidence;
  final String? errorMessage;
  final DateTime timestamp;
  final Map<String, dynamic>? detectionData;

  FaceAuthResponse({
    required this.requestId,
    required this.success,
    this.recognizedUserId,
    this.recognizedUserName,
    this.confidence,
    this.errorMessage,
    DateTime? timestamp,
    this.detectionData,
  }) : timestamp = timestamp ?? DateTime.now();

  factory FaceAuthResponse.fromJson(Map<String, dynamic> json) {
    return FaceAuthResponse(
      requestId: json['requestId'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      recognizedUserId: json['recognizedUserId'] as String?,
      recognizedUserName: json['recognizedUserName'] as String? ??
          json['name'] as String?, // Support backend 'name' field
      confidence: (json['confidence'] as num?)?.toDouble() ??
          (json['distance'] != null
              ? 1.0 - (json['distance'] as num).toDouble()
              : null),
      errorMessage: json['errorMessage'] as String? ?? json['error'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      detectionData: json['detectionData'] as Map<String, dynamic>? ??
          json['detections'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'success': success,
      if (recognizedUserId != null) 'recognizedUserId': recognizedUserId,
      if (recognizedUserName != null) 'recognizedUserName': recognizedUserName,
      if (confidence != null) 'confidence': confidence,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'timestamp': timestamp.toIso8601String(),
      if (detectionData != null) 'detectionData': detectionData,
    };
  }

  bool get isRecognized => success && recognizedUserId != null;
  bool get isUnknown => !success || recognizedUserId == null;
}

/// Face authentication session tracking
class FaceAuthSession {
  final String sessionId;
  final FaceAuthRequest request;
  final DateTime startTime;
  FaceAuthResponse? response;
  FaceAuthStatus status;
  String? errorMessage;

  FaceAuthSession({
    required this.sessionId,
    required this.request,
    DateTime? startTime,
    this.response,
    this.status = FaceAuthStatus.idle,
    this.errorMessage,
  }) : startTime = startTime ?? DateTime.now();

  Duration get duration => DateTime.now().difference(startTime);

  bool get isCompleted =>
      status == FaceAuthStatus.success ||
      status == FaceAuthStatus.failed ||
      status == FaceAuthStatus.timeout ||
      status == FaceAuthStatus.error;

  bool get isSuccess =>
      status == FaceAuthStatus.success && response?.success == true;

  void updateStatus(FaceAuthStatus newStatus, {String? error}) {
    status = newStatus;
    if (error != null) {
      errorMessage = error;
    }
  }

  void setResponse(FaceAuthResponse authResponse) {
    response = authResponse;
    if (authResponse.success && authResponse.isRecognized) {
      status = FaceAuthStatus.success;
    } else {
      status = FaceAuthStatus.failed;
      errorMessage = authResponse.errorMessage ?? 'Face not recognized';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'request': request.toJson(),
      'startTime': startTime.toIso8601String(),
      if (response != null) 'response': response!.toJson(),
      'status': status.name,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}
