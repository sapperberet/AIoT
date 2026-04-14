import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';

class BackCameraPreviewCard extends StatefulWidget {
  final bool visible;
  final String streamUrl;

  const BackCameraPreviewCard({
    super.key,
    required this.visible,
    required this.streamUrl,
  });

  @override
  State<BackCameraPreviewCard> createState() => _BackCameraPreviewCardState();
}

class _BackCameraPreviewCardState extends State<BackCameraPreviewCard> {
  VideoPlayerController? _controller;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant BackCameraPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible ||
        oldWidget.streamUrl != widget.streamUrl) {
      _syncController();
    }
  }

  Future<void> _syncController() async {
    if (!widget.visible) {
      await _disposeController();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }

    if (widget.streamUrl.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'Camera stream URL is empty';
          _loading = false;
        });
      }
      return;
    }

    await _disposeController();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resolvedUrl = await _resolveFinalStreamUrl(widget.streamUrl.trim());
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(resolvedUrl),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
      );

      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load camera preview';
        _loading = false;
      });
    }
  }

  Future<String> _resolveFinalStreamUrl(String inputUrl) async {
    final uri = Uri.parse(inputUrl);
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)..followRedirects = true;
      final streamed = await client.send(request).timeout(
            const Duration(seconds: 6),
          );
      final finalUri = streamed.request?.url;
      await streamed.stream.listen((_) {}).cancel();
      return (finalUri ?? uri).toString();
    } catch (_) {
      return inputUrl;
    } finally {
      client.close();
    }
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      await c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.visible) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Iconsax.camera, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Back Camera Preview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: _buildPreviewBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_error != null) {
      return _buildPlaceholder(
        icon: Iconsax.warning_2,
        text: _error!,
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return _buildPlaceholder(
        icon: Iconsax.camera,
        text: 'Waiting for stream...',
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildPlaceholder({required IconData icon, required String text}) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 26),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
