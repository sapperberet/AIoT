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
  bool _isDoorAnimating = false;
  bool _isGarageOpen = false;
  bool _isGarageAnimating = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _listenToAlarms();
    _listenToDoorState();
    _listenToGarageState();
    _listenToDeviceSync();
    _listenToThemeChanges();
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
    final deviceProvider = context.read<DeviceProvider>();
    final vizProvider = context.read<HomeVisualizationProvider>();

    // Listen to alarm changes and update visualization
    deviceProvider.addListener(() {
      final alarms = deviceProvider.activeAlarms;

      // Clear all previous visual alarms
      vizProvider.clearAllVisualAlarms();

      // Add new visual alarms
      for (var alarm in alarms) {
        vizProvider.triggerVisualAlarm(
          alarm.location,
          alarm.type,
          alarm.severity,
        );
      }

      // Send update to JavaScript
      _updateVisualization(vizProvider.getVisualizationCommand());
    });
  }

  void _listenToDoorState() {
    final vizProvider = context.read<HomeVisualizationProvider>();

    // Listen to door state changes from camera feed or other sources
    vizProvider.addListener(() {
      if (vizProvider.isDoorAnimating && !_isDoorAnimating) {
        // Trigger door animation in 3D
        debugPrint('🚪 Door state changed - triggering 3D animation');
        _webViewController.runJavaScript(
            vizProvider.isDoorOpen ? 'openDoor()' : 'closeDoor()');
        setState(() {
          _isDoorAnimating = true;
          _isDoorOpen = vizProvider.isDoorOpen;
        });

        // Reset after animation
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _isDoorAnimating = false;
            });
          }
        });
      }

      // Update door open state
      if (vizProvider.isDoorOpen != _isDoorOpen && !_isDoorAnimating) {
        setState(() {
          _isDoorOpen = vizProvider.isDoorOpen;
        });
        _webViewController.runJavaScript(
            vizProvider.isDoorOpen ? 'openDoor()' : 'closeDoor()');
      }
    });
  }

  void _listenToGarageState() {
    final vizProvider = context.read<HomeVisualizationProvider>();

    vizProvider.addListener(() {
      if (vizProvider.isGarageAnimating && !_isGarageAnimating) {
        debugPrint('🚗 Garage state changed - triggering 3D animation');
        _webViewController.runJavaScript(
            vizProvider.isGarageOpen ? 'openGarage()' : 'closeGarage()');
        setState(() {
          _isGarageAnimating = true;
          _isGarageOpen = vizProvider.isGarageOpen;
        });

        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            setState(() {
              _isGarageAnimating = false;
            });
          }
        });
      }

      if (vizProvider.isGarageOpen != _isGarageOpen && !_isGarageAnimating) {
        setState(() {
          _isGarageOpen = vizProvider.isGarageOpen;
        });
        _webViewController.runJavaScript(
            vizProvider.isGarageOpen ? 'openGarage()' : 'closeGarage()');
      }
    });
  }

  void _listenToDeviceSync() {
    final deviceProvider = context.read<DeviceProvider>();
    final vizProvider = context.read<HomeVisualizationProvider>();

    // Set visualization callback on device provider
    deviceProvider.setVisualizationCallback((deviceType, state) {
      vizProvider.syncFromDeviceState(deviceType, state);
      _syncDeviceToJS(deviceType, state);
    });
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
    }
  }

  /// Sync all device states to visualization on load
  void _syncDeviceStates() {
    final deviceProvider = context.read<DeviceProvider>();
    final states = deviceProvider.getDeviceStatesSummary();

    // Sync door
    if (states['door']?['isOpen'] == true) {
      _webViewController.runJavaScript('openDoor()');
    }

    // Sync garage
    if (states['garage']?['isOpen'] == true) {
      _webViewController.runJavaScript('openGarage()');
    }

    // Sync windows and lights via full state command
    final fullState = jsonEncode(states);
    _webViewController.runJavaScript('syncAllDeviceStates($fullState)');
  }

  void _listenToThemeChanges() {
    final settingsProvider = context.read<SettingsProvider>();
    settingsProvider.addListener(() {
      _syncThemeWithVisualization();
    });
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
    }
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
