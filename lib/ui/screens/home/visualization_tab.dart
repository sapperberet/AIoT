import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/providers/home_visualization_provider.dart';

class VisualizationTab extends StatefulWidget {
  const VisualizationTab({super.key});

  @override
  State<VisualizationTab> createState() => _VisualizationTabState();
}

class _VisualizationTabState extends State<VisualizationTab> {
  late WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _listenToAlarms();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
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
          },
        ),
      )
      ..loadFlutterAsset('assets/web/home_visualization.html');
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              // Reset camera view
              _webViewController.runJavaScript('resetCamera()');
            },
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }
}
