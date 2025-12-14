import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/providers/home_visualization_provider.dart';
import '../../../core/providers/settings_provider.dart';

class VisualizationTab extends StatefulWidget {
  const VisualizationTab({super.key});

  @override
  State<VisualizationTab> createState() => _VisualizationTabState();
}

class _VisualizationTabState extends State<VisualizationTab> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  bool _isDoorOpen = false;
  bool _isGarageOpen = false;

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
      AndroidWebViewController.enableDebugging(true);
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
          },
        ),
      )
      ..loadFlutterAsset('assets/web/home_visualization.html');
  }

  Future<void> _loadGlbModel() async {
    try {
      debugPrint('📦 Loading .glb model from assets...');
      // Use newer model from web folder
      final ByteData data = await rootBundle.load('assets/web/home_model.glb');
      final List<int> bytes = data.buffer.asUint8List();
      final String base64String = base64Encode(bytes);

      debugPrint('✅ .glb model loaded: ${bytes.length} bytes');
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
      case 'windows':
        final command = jsonEncode({'type': 'windows', 'state': state});
        _webViewController.runJavaScript('syncDeviceState($command)');
        break;
      case 'light':
      case 'lights':
        final command = jsonEncode({'type': 'lights', 'state': state});
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
        final state = parts[1];
        _handleDeviceStateFromVisualization(deviceType, state);
      }
      return;
    }
  }

  /// Handle device state changes from 3D visualization and sync to backend
  void _handleDeviceStateFromVisualization(String deviceType, String state) {
    final deviceProvider = context.read<DeviceProvider>();

    debugPrint('🔄 3D Visualization -> Backend: $deviceType = $state');

    switch (deviceType) {
      case 'door':
        final isOpen = state == 'open';
        deviceProvider.setDoorState(isOpen);
        break;
      case 'garage':
        final isOpen = state == 'open';
        deviceProvider.setGarageState(isOpen);
        break;
      case 'window':
        // Window state changes from 3D - format: window:windowName:state
        // Parse the state which may contain window name
        final parts = state.split(':');
        if (parts.length >= 2) {
          final windowName = parts[0];
          final windowState = parts[1];
          final isOpen = windowState == 'open';
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
        final isOn = state == 'on';
        // Toggle all lights in the device provider
        final currentlyAnyOn =
            deviceProvider.lightStates.values.any((on) => on);
        if (currentlyAnyOn != isOn) {
          deviceProvider.toggleAllLights();
        }
        break;
      case 'buzzer':
        final isActive = state == 'active';
        deviceProvider.setBuzzerState(isActive);
        break;
    }
  }

  /// Map 3D mesh window names to device provider window IDs
  String? _mapWindowNameToId(String meshName) {
    final nameLower = meshName.toLowerCase();
    if (nameLower.contains('front')) {
      return 'front_window';
    } else if (nameLower.contains('gate')) {
      return 'gate';
    } else if (nameLower.contains('back')) {
      return 'back_window';
    }
    // Try to use the mesh name as-is if no specific mapping
    return nameLower.replaceAll(' ', '_');
  }

  void _showRoomControls(String objectName, String objectType) {
    // Skip showing controls for interactive elements - they have their own panel in 3D
    if (objectType == 'door' ||
        objectType == 'garage' ||
        objectType == 'window') {
      debugPrint(
          '📍 Selected $objectType: $objectName - controls shown in 3D panel');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              objectName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.lightbulb),
              title: Text(AppLocalizations.of(context).t('control_lights')),
              trailing: Switch(
                value: false,
                onChanged: (value) {
                  // TODO: Control room lights
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.thermostat),
              title: Text(AppLocalizations.of(context).t('temperature')),
              subtitle: const Text('22°C'),
            ),
          ],
        ),
      ),
    );
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
