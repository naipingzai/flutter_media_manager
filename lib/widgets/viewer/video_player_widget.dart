import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 视频播放器组件 - 支持播放/暂停、进度控制、音量/亮度控制
class VideoPlayerWidget extends StatefulWidget {
  final String filePath;

  const VideoPlayerWidget({super.key, required this.filePath});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  double _volume = 1.0;
  double _brightness = 0.5;

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
    _disposePlayer();
    _hideControlsTimer?.cancel();
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
      setState(() {
        _isInitialized = true;
      });
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

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _showControls = true;
    });
    _startHideTimer();
  }

  void _seekTo(double value) {
    _controller?.seekTo(Duration(milliseconds: value.toInt()));
  }

  void _setVolume(double value) {
    _controller?.setVolume(value);
    setState(() => _volume = value);
  }

  void _setBrightness(double value) {
    setState(() => _brightness = value);
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final controller = _controller!;
    final position = controller.value.position;
    final duration = controller.value.duration;

    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
        if (_showControls) _startHideTimer();
      },
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

          // 中央播放/暂停按钮
          if (_showControls)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),

          // 底部控制条
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 进度条
                      Row(
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white30,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                                max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                                onChanged: _seekTo,
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // 音量 & 亮度控制
                      Row(
                        children: [
                          const Icon(Icons.volume_up, color: Colors.white70, size: 16),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white30,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _volume,
                                max: 1.0,
                                onChanged: _setVolume,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.brightness_6, color: Colors.white70, size: 16),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white30,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _brightness,
                                max: 1.0,
                                onChanged: _setBrightness,
                              ),
                            ),
                          ),
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
