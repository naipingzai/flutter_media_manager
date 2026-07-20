import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// 视频播放器组件
///
/// - 全屏手势：点击切换控制条显隐
/// - 统一控制按钮：播放/暂停、进度条、全屏
/// - [bottomPadding] 用于为外层底部操作栏留出空间
class VideoPlayerWidget extends StatefulWidget {
  final String filePath;
  final double bottomPadding;

  const VideoPlayerWidget({
    super.key,
    required this.filePath,
    this.bottomPadding = 0,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _disposePlayer();
      _initPlayer();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _disposePlayer();
    super.dispose();
  }

  void _disposePlayer() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  Future<void> _initPlayer() async {
    final controller = VideoPlayerController.file(File(widget.filePath));
    _controller = controller;

    controller.addListener(() {
      if (mounted) {
        setState(() {
          _isPlaying = controller.value.isPlaying;
        });
      }
    });

    await controller.initialize();
    if (mounted) {
      setState(() => _isInitialized = true);
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _startHideTimer();
    });
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
    _startHideTimer();
  }

  void _seekTo(double value) {
    _controller?.seekTo(Duration(milliseconds: value.toInt()));
  }

  void _toggleFullscreen() {
    // 简单切换屏幕方向
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    _startHideTimer();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildControlButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    final controller = _controller!;
    final position = controller.value.position;
    final duration = controller.value.duration;
    final maxMs =
        duration.inMilliseconds.toDouble().clamp(1, double.infinity).toDouble();
    final valueMs =
        position.inMilliseconds.toDouble().clamp(0, maxMs).toDouble();

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 视频画面
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),

          // 底部进度条（始终显示，播放/暂停和全屏按钮随控件显隐）
          Positioned(
            bottom: widget.bottomPadding,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                32,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (_showControls) ...[
                          _buildControlButton(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            _togglePlayPause,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: const SliderThemeData(
                              trackHeight: 4,
                              thumbShape:
                                  RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape:
                                  RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white30,
                              thumbColor: Colors.white,
                              overlayColor: Colors.white24,
                            ),
                            child: Slider(
                              value: valueMs,
                              max: maxMs,
                              onChanged: _seekTo,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                        if (_showControls) ...[
                          const SizedBox(width: 12),
                          _buildControlButton(
                              Icons.fullscreen, _toggleFullscreen),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
