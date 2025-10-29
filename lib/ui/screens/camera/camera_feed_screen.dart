import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class CameraFeedScreen extends StatefulWidget {
  const CameraFeedScreen({super.key});

  @override
  State<CameraFeedScreen> createState() => _CameraFeedScreenState();
}

class _CameraFeedScreenState extends State<CameraFeedScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDoorOpen = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() {
    final authProvider = context.read<AuthProvider>();
    final streamUrl = authProvider.getHlsStreamUrl();

    if (streamUrl == null) {
      setState(() {
        _errorMessage = 'Camera stream not available. Please connect to face recognition system.';
        _isLoading = false;
      });
      return;
    }

    // Initialize WebView for HLS streaming
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _errorMessage = 'Failed to load camera feed: ${error.description}';
              _isLoading = false;
            });
          },
        ),
      )
      ..loadHtmlString(_buildHlsPlayerHtml(streamUrl));
  }

  String _buildHlsPlayerHtml(String streamUrl) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      background: #000;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      overflow: hidden;
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
    }
    .status {
      position: absolute;
      top: 10px;
      left: 10px;
      background: rgba(0,0,0,0.7);
      color: #fff;
      padding: 8px 12px;
      border-radius: 8px;
      font-family: system-ui;
      font-size: 12px;
    }
    .error {
      color: #ff5252;
      text-align: center;
      padding: 20px;
      font-family: system-ui;
    }
  </style>
</head>
<body>
  <div id="status" class="status">Loading...</div>
  <video id="video" controls autoplay muted playsinline></video>
  
  <script>
    const video = document.getElementById('video');
    const status = document.getElementById('status');
    const streamUrl = '$streamUrl';
    
    if (Hls.isSupported()) {
      const hls = new Hls({
        enableWorker: true,
        lowLatencyMode: true,
        backBufferLength: 90
      });
      
      hls.loadSource(streamUrl);
      hls.attachMedia(video);
      
      hls.on(Hls.Events.MANIFEST_PARSED, function() {
        status.textContent = 'Live';
        status.style.background = 'rgba(76, 175, 80, 0.9)';
        video.play();
      });
      
      hls.on(Hls.Events.ERROR, function(event, data) {
        if (data.fatal) {
          status.textContent = 'Error: ' + data.type;
          status.style.background = 'rgba(244, 67, 54, 0.9)';
          
          switch(data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              hls.startLoad();
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              hls.recoverMediaError();
              break;
            default:
              hls.destroy();
              break;
          }
        }
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = streamUrl;
      video.addEventListener('loadedmetadata', function() {
        status.textContent = 'Live';
        status.style.background = 'rgba(76, 175, 80, 0.9)';
        video.play();
      });
    } else {
      document.body.innerHTML = '<div class="error">HLS not supported in this browser</div>';
    }
  </script>
</body>
</html>
    ''';
  }

  Future<void> _openDoor() async {
    final authProvider = context.read<AuthProvider>();
    
    setState(() {
      _isDoorOpen = true;
    });

    final success = await authProvider.openDoor();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Door opened successfully' : 'Failed to open door',
          ),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reset button after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
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
    final textColor = theme.colorScheme.onBackground;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        leading: FadeInLeft(
          child: IconButton(
            icon: Icon(Iconsax.arrow_left, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: FadeInDown(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isLoading
                      ? AppTheme.warningColor
                      : (_errorMessage != null
                          ? AppTheme.errorColor
                          : AppTheme.successColor),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isLoading
                              ? AppTheme.warningColor
                              : (_errorMessage != null
                                  ? AppTheme.errorColor
                                  : AppTheme.successColor))
                          .withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).t('camera_feed'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FadeInRight(
            child: IconButton(
              icon: Icon(Iconsax.refresh, color: textColor),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeCamera();
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Feed
          if (_errorMessage != null)
            Center(
              child: FadeIn(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.video_slash,
                      size: 80,
                      color: AppTheme.errorColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _initializeCamera();
                      },
                      icon: const Icon(Iconsax.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _webViewController),

          // Loading Indicator
          if (_isLoading && _errorMessage == null)
            Center(
              child: FadeIn(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: AppTheme.largeRadius,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting to camera...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _errorMessage == null
          ? FadeInUp(
              child: FloatingActionButton.extended(
                onPressed: _isDoorOpen ? null : _openDoor,
                backgroundColor: _isDoorOpen
                    ? AppTheme.successColor
                    : AppTheme.primaryColor,
                icon: Icon(
                  _isDoorOpen ? Iconsax.tick_circle : Iconsax.lock_slash,
                  color: Colors.white,
                ),
                label: Text(
                  _isDoorOpen ? 'Door Opened' : 'Open Door',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
