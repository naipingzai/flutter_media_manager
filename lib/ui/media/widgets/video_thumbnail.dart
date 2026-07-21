import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 视频缩略图组件
/// 使用 VideoPlayerController 提取视频第一帧作为预览图
class VideoThumbnail extends StatefulWidget {
  final String filePath;
  final double? aspectRatio;

  const VideoThumbnail({
    super.key,
    required this.filePath,
    this.aspectRatio,
  });

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    _controller = VideoPlayerController.file(File(widget.filePath));
    try {
      await _controller!.initialize();
      // seek到第一帧附近(100ms)获取清晰画面
      await _controller!.seekTo(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildPlaceholder(context);
    }
    if (!_initialized || _controller == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
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

  Widget _buildPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.play_arrow_rounded, color: cs.primary, size: 28),
        ),
      ),
    );
  }
}
