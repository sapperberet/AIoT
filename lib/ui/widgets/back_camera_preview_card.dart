import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';

class BackCameraPreviewCard extends StatefulWidget {
  final bool enabled;
  final bool visible;
  final String streamUrl;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onToggleVisibility;
  final bool compact;

  const BackCameraPreviewCard({
    super.key,
    required this.enabled,
    required this.visible,
    required this.streamUrl,
    required this.onToggle,
    required this.onToggleVisibility,
    this.compact = false,
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
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.streamUrl != widget.streamUrl) {
      _syncController();
    }
  }

  Future<void> _syncController() async {
    if (!widget.enabled) {
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
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
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
    final statusColor = widget.enabled ? Colors.green : Colors.orange;
    final previewHeight = widget.compact ? 92.0 : 178.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
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
              Icon(Iconsax.camera, size: 18, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Back Camera Preview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.compact)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Compact',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Switch(
                value: widget.enabled,
                onChanged: widget.onToggle,
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => widget.onToggleVisibility(!widget.visible),
                icon: Icon(
                  widget.visible ? Iconsax.eye : Iconsax.eye_slash,
                  size: 18,
                ),
                tooltip: widget.visible ? 'Hide preview' : 'Show preview',
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              Text(
                widget.visible ? 'Visible' : 'Hidden',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
          if (widget.visible) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: previewHeight,
                child: _buildPreviewBody(theme),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewBody(ThemeData theme) {
    if (!widget.enabled) {
      return _buildPlaceholder(
        icon: Iconsax.video_slash,
        text: 'Preview is off',
      );
    }

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
