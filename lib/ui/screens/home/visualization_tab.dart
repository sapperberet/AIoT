import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/providers/home_visualization_provider.dart';
import '../../../core/providers/settings_provider.dart';

class VisualizationTab extends StatefulWidget {
  const VisualizationTab({super.key});

  @override
  State<VisualizationTab> createState() => _VisualizationTabState();
}

class _VisualizationTabState extends State<VisualizationTab> {
  static const Duration _periodicSyncInterval = Duration(milliseconds: 500);
  static const Duration _bridgeEventDedupWindow = Duration(milliseconds: 700);

  late WebViewController _webViewController;
  bool _isLoading = true;
  bool _isDoorOpen = false;
  bool _isGarageOpen = false;
  Timer? _periodicSyncTimer;
  final Map<String, DateTime> _recentBridgeEvents = {};

  // Listener references for cleanup
  VoidCallback? _alarmListener;
  VoidCallback? _doorListener;
  VoidCallback? _garageListener;
  VoidCallback? _deviceSyncListener;
  VoidCallback? _themeListener;

  // Provider references
  DeviceProvider? _deviceProvider;
  HomeVisualizationProvider? _vizProvider;
  SettingsProvider? _settingsProvider;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    // Initialize local state from providers BEFORE setting up listeners
    _initializeLocalState();
    _listenToAlarms();
    _listenToDoorState();
    _listenToGarageState();
    _listenToDeviceSync();
    _listenToThemeChanges();
  }

  /// Initialize local state variables from providers to ensure sync
  void _initializeLocalState() {
    _vizProvider = context.read<HomeVisualizationProvider>();
    _deviceProvider = context.read<DeviceProvider>();

    // Sync local state from the visualization provider
    _isDoorOpen = _vizProvider!.isDoorOpen;
    _isGarageOpen = _vizProvider!.isGarageOpen;

    debugPrint(
        '🏠 Initialized local state - Door: $_isDoorOpen, Garage: $_isGarageOpen');
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();

    // Remove all listeners to prevent setState after dispose
    if (_alarmListener != null && _deviceProvider != null) {
      _deviceProvider!.removeListener(_alarmListener!);
    }
    if (_doorListener != null && _vizProvider != null) {
      _vizProvider!.removeListener(_doorListener!);
    }
    if (_garageListener != null && _vizProvider != null) {
      _vizProvider!.removeListener(_garageListener!);
    }
    if (_deviceSyncListener != null && _vizProvider != null) {
      _vizProvider!.removeListener(_deviceSyncListener!);
    }
    if (_themeListener != null && _settingsProvider != null) {
      _settingsProvider!.removeListener(_themeListener!);
    }

    // Clear visualization callback
    _deviceProvider?.setVisualizationCallback(null);

    super.dispose();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));

    // Enable hardware acceleration for WebGL on Android
    final platformController = _webViewController.platform;
    if (platformController is AndroidWebViewController) {
      // Enable WebGL and hardware acceleration
      // Debugging disabled to prevent animation spam in logs
      AndroidWebViewController.enableDebugging(false);
    }

    _webViewController
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        // Filter out spam messages from animation loop and gralloc
        final msg = message.message;
        if (msg.contains('animate') ||
            msg.contains('gralloc') ||
            msg.contains('requestAnimationFrame') ||
            msg.isEmpty) {
          return; // Silently ignore spam
        }
        // Only print meaningful console messages
        debugPrint('📍 Console [${message.level.name}]: $msg');
      })
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          // Filter out spam/heartbeat messages
          final msg = message.message;
          if (msg.contains('animate') ||
              msg.contains('heartbeat') ||
              msg.isEmpty) {
            return; // Silently ignore spam
          }
          // Handle meaningful messages from JavaScript/three.js
          debugPrint('Message from 3D view: $msg');
          _handleJavaScriptMessage(msg);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // Load the .glb model after page loads
            _loadGlbModel();
            // Sync theme with visualization
            _syncThemeWithVisualization();
            // Sync current device states
            _syncDeviceStates();
            _startPeriodicDeviceSync();
          },
        ),
      )
      ..loadFlutterAsset('assets/web/home_visualization.html');
  }

  void _startPeriodicDeviceSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(_periodicSyncInterval, (_) {
      if (!mounted || _isLoading) return;
      _syncDeviceStates();
    });
  }

  Future<void> _loadGlbModel() async {
    try {
      debugPrint('📦 Loading .glb model from assets...');
      final assetCandidates = <String>[
        'assets/3d/home_model.glb',
        'assets/web/home_model.glb',
      ];

      ByteData? data;
      String? loadedAssetPath;

      for (final assetPath in assetCandidates) {
        try {
          data = await rootBundle.load(assetPath);
          loadedAssetPath = assetPath;
          break;
        } catch (_) {
          // Try next candidate path.
        }
      }

      if (data == null || loadedAssetPath == null) {
        throw StateError('No GLB asset found in expected locations');
      }

      final List<int> bytes = data.buffer.asUint8List();
      final String base64String = base64Encode(bytes);

      debugPrint(
          '✅ .glb model loaded from $loadedAssetPath: ${bytes.length} bytes');
      debugPrint('📤 Sending to WebView...');

      await _webViewController.runJavaScript('''
        if (window.loadModelFromBase64) {
          window.loadModelFromBase64('$base64String');
        } else {
          console.error('loadModelFromBase64 function not found');
        }
      ''');

      debugPrint('✅ Model sent to WebView');
    } catch (e) {
      debugPrint('❌ Error loading .glb model: $e');
      debugPrint('⚠️ Falling back to placeholder house');
    }
  }

  void _listenToAlarms() {
    _deviceProvider = context.read<DeviceProvider>();
    _vizProvider = context.read<HomeVisualizationProvider>();

    // Listen to alarm changes and update visualization
    _alarmListener = () {
      if (!mounted) return;
      final alarms = _deviceProvider!.activeAlarms;

      // Clear all previous visual alarms
      _vizProvider!.clearAllVisualAlarms();

      // Add new visual alarms
      for (var alarm in alarms) {
        _vizProvider!.triggerVisualAlarm(
          alarm.location,
          alarm.type,
          alarm.severity,
        );
      }

      // Send update to JavaScript
      _updateVisualization(_vizProvider!.getVisualizationCommand());
    };
    _deviceProvider!.addListener(_alarmListener!);
  }

  void _listenToDoorState() {
    _vizProvider ??= context.read<HomeVisualizationProvider>();

    // Listen to door state changes from visualization provider
    _doorListener = () {
      if (!mounted) return;
      final shouldBeOpen = _vizProvider!.isDoorOpen;
      final currentLocalState = _isDoorOpen;

      // Only sync if state actually changed
      if (shouldBeOpen != currentLocalState) {
        debugPrint(
            '🚪 Door state changed: local=$currentLocalState -> provider=$shouldBeOpen - syncing to 3D');
        _isDoorOpen = shouldBeOpen;
        if (mounted) {
          setState(() {});
        }
        _webViewController
            .runJavaScript(shouldBeOpen ? 'openDoor()' : 'closeDoor()');
      }
    };
    _vizProvider!.addListener(_doorListener!);
  }

  void _listenToGarageState() {
    _vizProvider ??= context.read<HomeVisualizationProvider>();

    // Listen to garage state changes from visualization provider
    _garageListener = () {
      if (!mounted) return;
      final shouldBeOpen = _vizProvider!.isGarageOpen;
      final currentLocalState = _isGarageOpen;

      // Only sync if state actually changed
      if (shouldBeOpen != currentLocalState) {
        debugPrint(
            '🚗 Garage state changed: local=$currentLocalState -> provider=$shouldBeOpen - syncing to 3D');
        _isGarageOpen = shouldBeOpen;
        if (mounted) {
          setState(() {});
        }
        _webViewController
            .runJavaScript(shouldBeOpen ? 'openGarage()' : 'closeGarage()');
      }
    };
    _vizProvider!.addListener(_garageListener!);
  }

  void _listenToDeviceSync() {
    _deviceProvider ??= context.read<DeviceProvider>();
    _vizProvider ??= context.read<HomeVisualizationProvider>();

    // Set visualization callback on device provider (for direct sync to JS)
    // This handles the JS sync when DeviceProvider calls _syncToVisualization
    _deviceProvider!.setVisualizationCallback((deviceType, state) {
      if (!mounted) return;
      _syncDeviceToJS(deviceType, state);
    });

    // Also listen to vizProvider for any state changes (handles all sources)
    _deviceSyncListener = () {
      if (!mounted) return;
      // The door and garage listeners handle those separately
      // Here we handle windows, lights, buzzer
      final windowStates = _vizProvider!.windowStates;
      final lightStates = _vizProvider!.lightStates;
      final buzzerActive = _vizProvider!.isBuzzerActive;

      // Sync windows to JS
      if (windowStates.isNotEmpty) {
        final windowCmd =
            jsonEncode({'type': 'windows', 'state': windowStates});
        _webViewController.runJavaScript('syncDeviceState($windowCmd)');
      }

      // Sync lights to JS
      if (lightStates.isNotEmpty) {
        final lightCmd = jsonEncode({'type': 'lights', 'state': lightStates});
        _webViewController.runJavaScript('syncDeviceState($lightCmd)');
      }

      // Sync fans to JS
      final fanStates = _deviceProvider?.fanStates ?? {};
      if (fanStates.isNotEmpty) {
        final fanCmd = jsonEncode({'type': 'fans', 'state': fanStates});
        _webViewController.runJavaScript('syncDeviceState($fanCmd)');
      }

      // Sync buzzer to JS
      _webViewController.runJavaScript('setBuzzerState($buzzerActive)');
    };
    _vizProvider!.addListener(_deviceSyncListener!);
  }

  /// Sync device state to JavaScript
  void _syncDeviceToJS(String deviceType, Map<String, dynamic> state) {
    switch (deviceType) {
      case 'door':
        final isOpen = state['isOpen'] ?? false;
        _webViewController.runJavaScript(isOpen ? 'openDoor()' : 'closeDoor()');
        break;
      case 'garage':
        final isOpen = state['isOpen'] ?? false;
        _webViewController
            .runJavaScript(isOpen ? 'openGarage()' : 'closeGarage()');
        break;
      case 'window':
        final command = jsonEncode({'type': 'window', 'state': state});
        _webViewController.runJavaScript('syncDeviceState($command)');
        break;
      case 'windows':
        final command = jsonEncode({'type': 'windows', 'state': state});
        _webViewController.runJavaScript('syncDeviceState($command)');
        break;
      case 'light':
      case 'lights':
        final command = jsonEncode({'type': 'lights', 'state': state});
        _webViewController.runJavaScript('syncDeviceState($command)');
        break;
      case 'fan':
        final command = jsonEncode({'type': 'fan', 'state': state});
        _webViewController.runJavaScript('syncDeviceState($command)');
        break;
      case 'fans':
        final command = jsonEncode({'type': 'fans', 'state': state});
        _webViewController.runJavaScript('syncDeviceState($command)');
        break;
      case 'buzzer':
        final isActive = state['isActive'] ?? false;
        _webViewController.runJavaScript('setBuzzerState($isActive)');
        break;
      case 'rgb':
        // Sync RGB color and brightness to 3D visualization
        final color = state['color'] ?? 0xFFFFFF;
        final brightness = state['brightness'] ?? 100;
        final isOn = state['isOn'] ?? false;
        _webViewController.runJavaScript('setRGBColor($color, $brightness)');
        _webViewController.runJavaScript('toggleRGBLights($isOn)');
        break;
    }
  }

  /// Sync all device states to visualization on load
  void _syncDeviceStates() {
    final deviceProvider = context.read<DeviceProvider>();
    final states = deviceProvider.getDeviceStatesSummary();

    // Update local state tracking variables
    final doorOpen = states['door']?['isOpen'] == true;
    final garageOpen = states['garage']?['isOpen'] == true;

    debugPrint(
        '🔄 Syncing device states to WebView - Door: $doorOpen, Garage: $garageOpen');

    // Sync door and update local state
    if (doorOpen) {
      _webViewController.runJavaScript('openDoor()');
    } else {
      _webViewController.runJavaScript('closeDoor()');
    }
    _isDoorOpen = doorOpen;

    // Sync garage and update local state
    if (garageOpen) {
      _webViewController.runJavaScript('openGarage()');
    } else {
      _webViewController.runJavaScript('closeGarage()');
    }
    _isGarageOpen = garageOpen;

    // Sync windows and lights via full state command
    final fullState = jsonEncode(states);
    _webViewController.runJavaScript('syncAllDeviceStates($fullState)');

    // Sync RGB color and brightness
    final rgbColor = deviceProvider.rgbLightColor;
    final rgbBrightness = deviceProvider.rgbBrightness;
    final rgbOn = deviceProvider.lightStates['rgb'] ?? false;
    _webViewController.runJavaScript('setRGBColor($rgbColor, $rgbBrightness)');
    _webViewController.runJavaScript('toggleRGBLights($rgbOn)');
  }

  void _listenToThemeChanges() {
    _settingsProvider = context.read<SettingsProvider>();
    _themeListener = () {
      if (!mounted) return;
      _syncThemeWithVisualization();
    };
    _settingsProvider!.addListener(_themeListener!);
  }

  void _syncThemeWithVisualization() {
    final settingsProvider = context.read<SettingsProvider>();
    final theme = Theme.of(context);

    // Get the primary color from the current theme
    final primaryColor = theme.colorScheme.primary;
    final r = primaryColor.red;
    final g = primaryColor.green;
    final b = primaryColor.blue;

    // Sync background color with theme
    final isDarkMode = settingsProvider.themeMode == ThemeMode.dark ||
        (settingsProvider.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    if (isDarkMode) {
      // For dark mode, use a darker version of the primary color
      _webViewController.runJavaScript('''
        if (window.setBackgroundColor) {
          window.setBackgroundColor(${(r * 0.2).round()}, ${(g * 0.2).round()}, ${(b * 0.2).round()});
        }
      ''');
    } else {
      // For light mode, use a lighter background
      _webViewController.runJavaScript('''
        if (window.setBackgroundColor) {
          window.setBackgroundColor(240, 240, 245);
        }
      ''');
    }

    debugPrint('🎨 Theme synced with 3D visualization');
  }

  void _updateVisualization(String command) {
    _webViewController.runJavaScript(
      'updateAlarms($command)',
    );
  }

  void _handleJavaScriptMessage(String message) {
    // Handle tap events from 3D view
    // Format: tap:FormattedName:elementType (e.g., "tap:Front Door:door")
    if (message.startsWith('tap:')) {
      final parts = message.substring(4).split(':');
      final objectName = parts.isNotEmpty ? parts[0] : 'Unknown';
      final objectType = parts.length > 1 ? parts[1] : 'room';
      _showRoomControls(objectName, objectType);
      return;
    }

    // Handle device state changes from 3D visualization (bidirectional sync)
    // Format: deviceStateChanged:deviceType:state (e.g., "deviceStateChanged:door:open")
    if (message.startsWith('deviceStateChanged:')) {
      final parts = message.substring('deviceStateChanged:'.length).split(':');
      if (parts.length >= 2) {
        final deviceType = parts[0];
        final state = parts.sublist(1).join(':');
        if (!_shouldProcessBridgeEvent(deviceType, state)) {
          return;
        }
        _handleDeviceStateFromVisualization(deviceType, state);
      }
      return;
    }
  }

  bool _shouldProcessBridgeEvent(String deviceType, String state) {
    final normalizedDevice = deviceType.trim().toLowerCase();
    final normalizedState = state.trim().toLowerCase();
    final key = '$normalizedDevice:$normalizedState';
    final now = DateTime.now();
    final lastSeen = _recentBridgeEvents[key];

    _recentBridgeEvents.removeWhere(
      (_, timestamp) => now.difference(timestamp) > const Duration(seconds: 5),
    );

    if (lastSeen != null &&
        now.difference(lastSeen) < _bridgeEventDedupWindow) {
      debugPrint('🔁 Ignoring duplicate 3D bridge event: $key');
      return false;
    }

    _recentBridgeEvents[key] = now;
    return true;
  }

  /// Handle device state changes from 3D visualization and sync to backend
  void _handleDeviceStateFromVisualization(String deviceType, String state) {
    final deviceProvider = context.read<DeviceProvider>();
    final normalizedState = state.trim().toLowerCase();

    debugPrint(
        '🔄 3D Visualization -> Backend: $deviceType = $normalizedState');

    switch (deviceType) {
      case 'door':
        final isOpen = _parseOpenCloseState(normalizedState);
        if (isOpen == null) {
          debugPrint(
              '⚠️ Ignoring unknown door state from 3D: $normalizedState');
          return;
        }
        if (deviceProvider.isMainDoorOpen != isOpen) {
          deviceProvider.setDoorState(isOpen);
        }
        break;
      case 'garage':
        final isOpen = _parseOpenCloseState(normalizedState);
        if (isOpen == null) {
          debugPrint(
              '⚠️ Ignoring unknown garage state from 3D: $normalizedState');
          return;
        }
        if (deviceProvider.isGarageDoorOpen != isOpen) {
          deviceProvider.setGarageState(isOpen);
        }
        break;
      case 'gate':
        final isOpen = _parseOpenCloseState(normalizedState);
        if (isOpen == null) {
          debugPrint(
              '⚠️ Ignoring unknown gate state from 3D: $normalizedState');
          return;
        }
        final currentGateState = deviceProvider.windowStates['gate'] ?? false;
        if (currentGateState != isOpen) {
          deviceProvider.toggleWindow('gate');
        }
        break;
      case 'window':
        // Window state changes from 3D - format: window:windowName:state
        // Parse the state which may contain window name
        final parts = normalizedState.split(':');
        if (parts.length >= 2) {
          final windowName = parts[0];
          final windowState = parts[1];
          final isOpen = _parseOpenCloseState(windowState);
          if (isOpen == null) return;

          // Keep gate on its own path to avoid side effects on regular windows.
          final lowerWindowName = windowName.toLowerCase();
          if (lowerWindowName.contains('gate') ||
              lowerWindowName.contains('glass')) {
            final currentGateState =
                deviceProvider.windowStates['gate'] ?? false;
            if (currentGateState != isOpen) {
              deviceProvider.toggleWindow('gate');
            }
            return;
          }

          // Map 3D window name to device provider window ID
          final windowId = _mapWindowNameToId(windowName);
          if (windowId != null) {
            // Use toggleWindow if state differs, or set directly if method exists
            final currentState = deviceProvider.windowStates[windowId] ?? false;
            if (currentState != isOpen) {
              deviceProvider.toggleWindow(windowId);
            }
          }
        }
        break;
      case 'light':
      case 'lights':
        // Light state changes from 3D
        final isOn = normalizedState == 'on' || normalizedState == 'active';
        // Toggle all lights in the device provider
        final currentlyAnyOn =
            deviceProvider.lightStates.values.any((on) => on);
        if (currentlyAnyOn != isOn) {
          deviceProvider.toggleAllLights();
        }
        break;
      case 'buzzer':
        final isActive = normalizedState == 'active' || normalizedState == 'on';
        if (deviceProvider.isBuzzerActive != isActive) {
          deviceProvider.setBuzzerState(isActive);
        }
        break;
      case 'fan':
      case 'fans':
        int speed;
        if (normalizedState == 'in') {
          speed = 1;
        } else if (normalizedState == 'out') {
          speed = 2;
        } else {
          speed = 0;
        }

        final currentSpeed = deviceProvider.fanStates['kitchen'] ?? 0;
        if (currentSpeed != speed) {
          deviceProvider.setFanSpeed('kitchen', speed);
        }
        break;
    }
  }

  bool? _parseOpenCloseState(String state) {
    switch (state) {
      case 'open':
      case 'opened':
      case 'on':
      case 'true':
      case '1':
        return true;
      case 'close':
      case 'closed':
      case 'off':
      case 'false':
      case '0':
        return false;
      default:
        return null;
    }
  }

  /// Map 3D mesh window names to device provider window IDs
  String? _mapWindowNameToId(String meshName) {
    final nameLower = meshName.toLowerCase();
    // In the updated 3D model, the gate is represented by Glass meshes.
    if (nameLower.contains('glass')) {
      return 'gate';
    }
    // Check gate first so names like "front_gate" never map to front_window.
    if (nameLower.contains('gate')) {
      return 'gate';
    }
    if (nameLower.contains('front')) {
      return 'front_window';
    } else if (nameLower.contains('upper_window') ||
        nameLower.contains('window_mesh')) {
      // Current firmware endpoint tracks a single front window actuator.
      return 'front_window';
    } else if (nameLower.contains('side')) {
      // side_window was replaced in the model; route legacy names to front window.
      return 'front_window';
    } else if (nameLower.contains('back')) {
      return 'back_window';
    }
    // Try to use the mesh name as-is if no specific mapping
    return nameLower.replaceAll(' ', '_');
  }

  void _showRoomControls(String objectName, String objectType) {
    // Don't show any control menu for non-interactive elements
    // Interactive elements (door, garage, window) have their own panel in the 3D view
    // Other elements (roof, yard, walls, etc.) don't need controls
    debugPrint('📍 Selected: $objectName (type: $objectType)');
    return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Stack(
      children: [
        WebViewWidget(
          controller: _webViewController,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
        if (_isLoading)
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),

        // Control buttons row - hidden on mobile (controls are in the drawer)
        if (!isMobile)
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Reset camera button
                FadeInUp(
                  delay: const Duration(milliseconds: 100),
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      debugPrint('🎥 Resetting camera view');
                      _webViewController.runJavaScript('resetCamera()');
                    },
                    child: const Icon(Icons.center_focus_strong),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
