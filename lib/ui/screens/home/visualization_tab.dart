import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/providers/home_visualization_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _listenToAlarms();
    _listenToDoorState();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        // Silently handle console messages to prevent serialization crashes
        // The WebView plugin has issues serializing complex objects in console messages
        debugPrint('📍 Console [${message.level.name}]: ${message.message}');
      })
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          // Handle messages from JavaScript/three.js
          debugPrint('Message from 3D view: ${message.message}');
          _handleJavaScriptMessage(message.message);
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
          },
        ),
      )
      ..loadFlutterAsset('assets/web/home_visualization.html');
  }

  Future<void> _loadGlbModel() async {
    try {
      debugPrint('📦 Loading .glb model from assets...');
      final ByteData data = await rootBundle.load('assets/3d/home_model.glb');
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
        _webViewController.runJavaScript('openDoor()');
        setState(() {
          _isDoorAnimating = true;
          _isDoorOpen = true;
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
      if (vizProvider.isDoorOpen != _isDoorOpen) {
        setState(() {
          _isDoorOpen = vizProvider.isDoorOpen;
        });
      }
    });
  }

  void _updateVisualization(String command) {
    _webViewController.runJavaScript(
      'updateAlarms($command)',
    );
  }

  void _handleJavaScriptMessage(String message) {
    // Handle tap events from 3D view
    // Example: User taps on a room to control lights
    if (message.startsWith('tap:')) {
      final room = message.substring(4);
      _showRoomControls(room);
    }
  }

  void _showRoomControls(String room) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room,
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

  Future<void> _openDoor() async {
    if (_isDoorAnimating || _isDoorOpen) return;

    setState(() {
      _isDoorAnimating = true;
      _isDoorOpen = true;
    });

    // Trigger 3D door animation
    debugPrint('🚪 Triggering 3D door animation');
    _webViewController.runJavaScript('openDoor()');

    // Also trigger actual door opening via API
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.openDoor();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '✅ Door opened successfully!' : '❌ Failed to open door',
          ),
          backgroundColor:
              success ? AppTheme.successColor : AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reset after animation completes
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _isDoorAnimating = false;
          });
        }
      });

      // Auto-close door state after 6 seconds
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() {
            _isDoorOpen = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (_isLoading)
          Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),

        // Control buttons row
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Door control button
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: FloatingActionButton.extended(
                  onPressed:
                      (_isDoorAnimating || _isDoorOpen) ? null : _openDoor,
                  backgroundColor: _isDoorOpen
                      ? AppTheme.successColor
                      : (_isDoorAnimating
                          ? AppTheme.warningColor
                          : AppTheme.primaryColor),
                  icon: Icon(
                    _isDoorOpen
                        ? Iconsax.tick_circle
                        : (_isDoorAnimating
                            ? Iconsax.timer_1
                            : Iconsax.lock_slash),
                    color: Colors.white,
                  ),
                  label: Text(
                    _isDoorOpen
                        ? 'Door Opened'
                        : (_isDoorAnimating ? 'Opening...' : 'Open Door'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

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
